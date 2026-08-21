#!/usr/bin/env python3
import socket
import select
import sys
import argparse

def prepare_payload(raw_payload, cdn_ip, ssh_port, sni):
    """
    Mengubah variabel dinamis LuCI menjadi string nyata
    dan mengubahnya menjadi format bytes untuk dikirim via socket.
    """
    payload = raw_payload.replace('[crlf]', '\r\n')
    payload = payload.replace('[host]', cdn_ip)
    payload = payload.replace('[port]', str(ssh_port))
    payload = payload.replace('[sni]', sni)
    
    # Payload HTTP/WS wajib diakhiri dengan double CRLF (Enter 2x)
    if not payload.endswith('\r\n\r\n'):
        payload += '\r\n\r\n'
        
    return payload.encode('utf-8')

def main():
    # Menangkap argumen yang dilempar dari sshws-core.sh
    parser = argparse.ArgumentParser(description="SSH WS Proxy Injector")
    parser.add_argument('--listen', type=int, required=True)
    parser.add_argument('--target_ip', type=str, required=True)
    parser.add_argument('--target_port', type=int, required=True)
    parser.add_argument('--ssh_port', type=int, required=True)
    parser.add_argument('--sni', type=str, required=True)
    parser.add_argument('--payload', type=str, required=True)
    args = parser.parse_args()

    # Memproses custom payload
    final_payload = prepare_payload(args.payload, args.target_ip, args.ssh_port, args.sni)

    # 1. MEMBUAT LOCAL LISTENER (Menunggu Klien SSH)
    local_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    local_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        local_server.bind(('127.0.0.1', args.listen))
        local_server.listen(1)
        print(f"[*] Injector siap di 127.0.0.1:{args.listen}...")
    except Exception as e:
        print(f"[!] Gagal membuka port lokal {args.listen}: {e}")
        sys.exit(1)

    while True:
        try:
            # Menerima ketukan pintu dari 'ncat' (ProxyCommand SSH)
            client_socket, addr = local_server.accept()
            print(f"[*] Menerima koneksi lokal dari SSH Client {addr}")

            # 2. KONEKSI KE CDN SERVER
            remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_socket.settimeout(10) # Set timeout 10 detik saat awal koneksi
            
            print(f"[*] Menghubungi CDN Server {args.target_ip}:{args.target_port}...")
            remote_socket.connect((args.target_ip, args.target_port))

            # 3. MENGIRIM CUSTOM PAYLOAD
            print("[*] Mengirimkan HTTP Custom Payload...")
            remote_socket.sendall(final_payload)
            
            # Membaca respons pertama dari server CDN (Cek Handshake)
            response = remote_socket.recv(4096)
            if b'101' not in response and b'200' not in response:
                print(f"[!] Peringatan: Respon tidak biasa dari CDN: {response[:50]}")
            else:
                print("[*] Handshake berhasil! Pipa WebSocket / SSH terbuka.")

            # Menghapus batasan timeout agar tunnel bisa berjalan lama tanpa terputus
            remote_socket.settimeout(None)
            client_socket.settimeout(None)

            # 4. PROSES BRIDGING (Mengalirkan Data Dua Arah)
            # Ini yang mengubah Python menjadi pipa pralon transparan
            sockets_to_monitor = [client_socket, remote_socket]
            
            while True:
                # Modul 'select' akan memantau socket mana yang sedang ada aliran data
                ready_to_read, _, _ = select.select(sockets_to_monitor, [], [])
                
                # Arah: OpenWrt Lokal -> Internet VPS
                if client_socket in ready_to_read:
                    data = client_socket.recv(8192)
                    if not data:
                        break # Klien SSH lokal menutup koneksi
                    remote_socket.sendall(data)
                    
                # Arah: Internet VPS -> OpenWrt Lokal
                if remote_socket in ready_to_read:
                    data = remote_socket.recv(8192)
                    if not data:
                        break # Server VPS memutus koneksi
                    client_socket.sendall(data)
                    
        except KeyboardInterrupt:
            print("\n[*] Mematikan Injector...")
            break
        except Exception as e:
            print(f"[!] Error pada terowongan (Tunnel putus): {e}")
        finally:
            # Memastikan koneksi ditutup dengan bersih setiap kali putus
            if 'client_socket' in locals():
                client_socket.close()
            if 'remote_socket' in locals():
                remote_socket.close()

if __name__ == '__main__':
    main()