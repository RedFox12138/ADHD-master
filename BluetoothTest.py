import bluetooth
import time
from datetime import datetime


def receive_bluetooth_data():
    # 蓝牙设备配置
    host_address = "FC:A8:9B:49:BA:56"  # 替换为你的单片机蓝牙MAC地址
    port = 1  # RFCOMM端口，通常是1

    try:
        # 创建蓝牙Socket
        sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
        sock.connect((host_address, port))
        print(f"成功连接到蓝牙设备 {host_address}")

        # 创建数据文件（可选）
        filename = f"bluetooth_data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        with open(filename, 'w') as file:
            print(f"数据将保存到: {filename}")

            while True:
                try:
                    # 接收数据（假设是UTF-8编码的字符串）
                    data = sock.recv(1024).decode('utf-8').strip()
                    if data:
                        timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
                        print(f"[{timestamp}] 收到数据: {data}")

                        # 写入文件（可选）
                        file.write(f"{timestamp},{data}\n")
                        file.flush()  # 实时写入

                except UnicodeDecodeError:
                    print("警告: 收到非UTF-8数据，尝试原始字节模式...")
                    data = sock.recv(1024)
                    print(f"原始字节: {data.hex()}")

    except Exception as e:
        print(f"发生错误: {e}")
    finally:
        sock.close()
        print("蓝牙连接已关闭")


if __name__ == "__main__":
    receive_bluetooth_data()