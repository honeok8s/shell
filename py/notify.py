import subprocess
import json
import urllib.request

# 配置部分
BARK_API_URL = "https://api.honeok.de/to73XJ2pqf6HfHM1234567/"
TITLE = "天气警报"
CITY = 'Chengdu'  # 替换为你想查询的城市名称

def get_weather(city):
    """通过 Shell 命令获取城市的天气信息"""
    try:
        # 使用 curl 命令从 wttr.in 获取天气信息
        result = subprocess.run(
            ['curl', '-s', f'wttr.in/{city}?format=%t,%h,%w,%c'],
            stdout=subprocess.PIPE,
            text=True
        )
        weather_info = result.stdout.strip()
        
        if weather_info:
            temperature, humidity, wind, weather = weather_info.split(',')
            alert_message = (
                f"城市: {city}\n"
                f"温度: {temperature}\n"
                f"湿度: {humidity}\n"
                f"风速: {wind}\n"
                f"天气: {weather}"
            )
            return alert_message
        else:
            print("获取天气信息失败")
            return None
    except Exception as e:
        print(f"获取天气信息失败: {e}")
        return None

def send_bark_notification(message):
    """通过 Bark API 发送通知"""
    data = {
        "title": TITLE,
        "body": message
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        req = urllib.request.Request(BARK_API_URL, data=json.dumps(data).encode(), headers=headers)
        with urllib.request.urlopen(req) as response:
            response.read()
    except Exception as e:
        print(f"发送通知失败: {e}")

if __name__ == '__main__':
    weather_message = get_weather(CITY)
    if weather_message:
        send_bark_notification(weather_message)

