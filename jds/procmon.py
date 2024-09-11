import subprocess
import json
import requests

# Bark API 回调接口
bark_url = "x"
title = "P8_CN_测试服务器告警"

# 执行 ps 命令获取进程信息
def run_ps_command(sort_by, threshold, field_index):
    result = subprocess.run(
        ["ps", "-eo", "pid,comm,%mem,%cpu", f"--sort=-{sort_by}"],
        stdout=subprocess.PIPE,
        text=True
    )
    output = result.stdout.strip().split("\n")

    # 跳过标题行
    alerts = []
    for line in output[1:]:
        fields = line.split()
        if len(fields) < 4:
            continue  # 跳过不完整的行
        try:
            pid = fields[0]
            # 从字段中提取命令部分
            # 找到 %mem 或 %cpu 的位置
            if sort_by == "%mem":
                mem_usage = fields[-2]
                cpu_usage = fields[-1]
            else:
                mem_usage = fields[-1]
                cpu_usage = fields[-1]

            # 取出命令部分
            name = " ".join(fields[1:-2]) if sort_by == "%mem" else " ".join(fields[1:-1])

            usage = float(mem_usage.replace(',', '.')) if sort_by == "%mem" else float(cpu_usage.replace(',', '.'))
            if usage > threshold:
                if sort_by == "%mem":
                    alerts.append(f"进程: {name} (PID: {pid}) 占用内存: {usage:.1f}%")
                else:
                    alerts.append(f"进程: {name} (PID: {pid}) 占用CPU: {usage:.1f}%")
        except ValueError as e:
            print(f"解析错误: {e}，行内容: {line}")
    return "\n".join(alerts)

# 获取内存和 CPU 占用警报
memory_alert = run_ps_command("%mem", 30, 2)
cpu_alert = run_ps_command("%cpu", 30, 3)

# 合并警报信息
alert_message = ""
if memory_alert:
    alert_message += f"内存占用警报:\n{memory_alert}\n"

if cpu_alert:
    alert_message += f"CPU占用警报:\n{cpu_alert}\n"

# 格式化并发送 Bark 通知
if alert_message:
    data = {
        "title": title,
        "body": alert_message
    }
    headers = {
        "Content-Type": "application/json"
    }
    requests.post(bark_url, headers=headers, data=json.dumps(data))