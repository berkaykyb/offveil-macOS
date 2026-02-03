import socket
import select
import threading
import struct


class DPIBypass:
    def __init__(self, local_host='127.0.0.1', local_port=8080):
        self.local_host = local_host
        self.local_port = local_port
        self.running = False
        self.server_socket = None
        
    def start(self):
        self.running = True
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.local_host, self.local_port))
        self.server_socket.listen(100)
        
        print(f"DPI Bypass proxy running on {self.local_host}:{self.local_port}")
        
        while self.running:
            try:
                client_socket, addr = self.server_socket.accept()
                thread = threading.Thread(target=self.handle_client, args=(client_socket,))
                thread.daemon = True
                thread.start()
            except:
                break
    
    def stop(self):
        self.running = False
        if self.server_socket:
            self.server_socket.close()
    
    def handle_client(self, client_socket):
        try:
            request = client_socket.recv(4096)
            if not request:
                client_socket.close()
                return
            
            first_line = request.split(b'\n')[0]
            url = first_line.split(b' ')[1]
            
            http_pos = url.find(b'://')
            if http_pos == -1:
                temp = url
            else:
                temp = url[(http_pos + 3):]
            
            port_pos = temp.find(b':')
            
            webserver_pos = temp.find(b'/')
            if webserver_pos == -1:
                webserver_pos = len(temp)
            
            webserver = ""
            port = 80
            if port_pos == -1 or webserver_pos < port_pos:
                port = 80
                webserver = temp[:webserver_pos]
            else:
                port = int((temp[(port_pos + 1):])[:webserver_pos - port_pos - 1])
                webserver = temp[:port_pos]
            
            if b'CONNECT' in first_line:
                self.handle_https(client_socket, webserver.decode(), port, request)
            else:
                self.handle_http(client_socket, webserver.decode(), port, request)
                
        except Exception as e:
            print(f"Error handling client: {e}")
        finally:
            client_socket.close()
    
    def handle_https(self, client_socket, host, port, request):
        try:
            remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_socket.connect((host, port))
            
            client_socket.send(b'HTTP/1.1 200 Connection Established\r\n\r\n')
            
            client_data = client_socket.recv(4096)
            if client_data:
                fragmented = self.fragment_sni(client_data)
                for fragment in fragmented:
                    remote_socket.send(fragment)
            
            self.forward_data(client_socket, remote_socket)
            
        except Exception as e:
            print(f"HTTPS Error: {e}")
        finally:
            remote_socket.close()
    
    def handle_http(self, client_socket, host, port, request):
        try:
            remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_socket.connect((host, port))
            remote_socket.send(request)
            
            self.forward_data(client_socket, remote_socket)
            
        except Exception as e:
            print(f"HTTP Error: {e}")
        finally:
            remote_socket.close()
    
    def fragment_sni(self, data):
        if len(data) < 100:
            return [data]
        
        try:
            if data[0] == 0x16:
                sni_pos = data.find(b'\x00\x00')
                if sni_pos > 50:
                    split_pos = sni_pos - 20
                    return [data[:split_pos], data[split_pos:]]
        except:
            pass
        
        return [data]
    
    def forward_data(self, client_socket, remote_socket):
        sockets = [client_socket, remote_socket]
        timeout = 60
        
        while True:
            try:
                readable, _, _ = select.select(sockets, [], [], timeout)
                if not readable:
                    break
                
                for sock in readable:
                    data = sock.recv(4096)
                    if not data:
                        return
                    
                    if sock is client_socket:
                        remote_socket.send(data)
                    else:
                        client_socket.send(data)
            except:
                break
