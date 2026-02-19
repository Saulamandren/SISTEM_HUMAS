# File: backend/app/utils/email_service.py

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import current_app
from datetime import datetime


class EmailService:
    """Service untuk mengirim email notifications"""
    
    @staticmethod
    def send_email(to_email: str, subject: str, body_html: str, body_text: str = None):
        """
        Mengirim email menggunakan SMTP Gmail
        
        Args:
            to_email (str): Email penerima
            subject (str): Subject email
            body_html (str): Konten email dalam format HTML
            body_text (str): Konten email dalam format plain text (optional)
            
        Returns:
            tuple: (success: bool, message: str)
        """
        try:
            # Buat message
            message = MIMEMultipart('alternative')
            message['From'] = current_app.config['MAIL_DEFAULT_SENDER']
            message['To'] = to_email
            message['Subject'] = f"[{current_app.config['APP_NAME']}] {subject}"
            
            # Attach text version
            if body_text:
                part1 = MIMEText(body_text, 'plain')
                message.attach(part1)
            
            # Attach HTML version
            part2 = MIMEText(body_html, 'html')
            message.attach(part2)
            
            # Connect ke SMTP server
            with smtplib.SMTP(current_app.config['MAIL_SERVER'], 
                            current_app.config['MAIL_PORT']) as server:
                server.starttls()
                server.login(
                    current_app.config['MAIL_USERNAME'],
                    current_app.config['MAIL_PASSWORD']
                )
                server.send_message(message)
            
            return True, "Email berhasil dikirim"
            
        except Exception as e:
            error_msg = f"Gagal mengirim email: {str(e)}"
            print(error_msg)
            return False, error_msg
    
    
    @staticmethod
    def send_welcome_email(user_email: str, full_name: str, username: str):
        """Kirim welcome email untuk user baru"""
        subject = "Selamat Datang di Sistem Informasi HUMAS"
        
        body_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: #1e3a8a; color: white; padding: 20px; text-align: center; }}
                .content {{ padding: 20px; background-color: #f9fafb; }}
                .button {{ 
                    display: inline-block; 
                    padding: 10px 20px; 
                    background-color: #3b82f6; 
                    color: white; 
                    text-decoration: none; 
                    border-radius: 5px; 
                    margin-top: 20px;
                }}
                .footer {{ padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Selamat Datang!</h1>
                </div>
                <div class="content">
                    <p>Halo <strong>{full_name}</strong>,</p>
                    
                    <p>Akun Anda telah berhasil dibuat di <strong>Sistem Informasi HUMAS Politeknik Siber dan Sandi Negara</strong>.</p>
                    
                    <p><strong>Detail Akun:</strong></p>
                    <ul>
                        <li>Username: <strong>{username}</strong></li>
                        <li>Email: <strong>{user_email}</strong></li>
                    </ul>
                    
                    <p>Silakan login menggunakan kredensial yang telah Anda buat untuk mulai menggunakan sistem.</p>
                    
                    <a href="{current_app.config['FRONTEND_URL']}/login" class="button">
                        Login Sekarang
                    </a>
                    
                    <p style="margin-top: 20px; color: #ef4444;">
                        <strong>Penting:</strong> Jangan bagikan password Anda kepada siapa pun.
                    </p>
                </div>
                <div class="footer">
                    <p>Email ini dikirim otomatis oleh sistem. Mohon tidak membalas email ini.</p>
                    <p>&copy; 2026 Politeknik Siber dan Sandi Negara. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        body_text = f"""
        Selamat Datang!
        
        Halo {full_name},
        
        Akun Anda telah berhasil dibuat di Sistem Informasi HUMAS Politeknik Siber dan Sandi Negara.
        
        Detail Akun:
        - Username: {username}
        - Email: {user_email}
        
        Silakan login menggunakan kredensial yang telah Anda buat.
        
        Penting: Jangan bagikan password Anda kepada siapa pun.
        
        ---
        Email ini dikirim otomatis. Mohon tidak membalas.
        © 2026 Politeknik Siber dan Sandi Negara
        """
        
        return EmailService.send_email(user_email, subject, body_html, body_text)
    
    
    @staticmethod
    def send_password_changed_notification(user_email: str, full_name: str):
        """Notifikasi password berhasil diubah"""
        subject = "Password Anda Telah Diubah"
        
        body_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: #059669; color: white; padding: 20px; text-align: center; }}
                .content {{ padding: 20px; background-color: #f9fafb; }}
                .alert {{ 
                    background-color: #fef3c7; 
                    border-left: 4px solid #f59e0b; 
                    padding: 15px; 
                    margin: 20px 0; 
                }}
                .footer {{ padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Password Berhasil Diubah</h1>
                </div>
                <div class="content">
                    <p>Halo <strong>{full_name}</strong>,</p>
                    
                    <p>Kami menginformasikan bahwa password akun Anda telah berhasil diubah pada:</p>
                    <p><strong>{datetime.now().strftime('%d %B %Y, %H:%M:%S WIB')}</strong></p>
                    
                    <div class="alert">
                        <strong>⚠️ Perhatian:</strong> Jika Anda tidak melakukan perubahan ini, 
                        segera hubungi administrator sistem atau ubah password Anda.
                    </div>
                    
                    <p>Untuk keamanan akun Anda:</p>
                    <ul>
                        <li>Jangan bagikan password kepada siapa pun</li>
                        <li>Gunakan password yang kuat dan unik</li>
                        <li>Ubah password secara berkala</li>
                    </ul>
                </div>
                <div class="footer">
                    <p>Email ini dikirim otomatis oleh sistem.</p>
                    <p>&copy; 2026 Politeknik Siber dan Sandi Negara.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        body_text = f"""
        Password Berhasil Diubah
        
        Halo {full_name},
        
        Password akun Anda telah berhasil diubah pada: {datetime.now().strftime('%d %B %Y, %H:%M:%S WIB')}
        
        PERHATIAN: Jika Anda tidak melakukan perubahan ini, segera hubungi administrator.
        
        Untuk keamanan akun:
        - Jangan bagikan password kepada siapa pun
        - Gunakan password yang kuat dan unik
        - Ubah password secara berkala
        
        ---
        © 2026 Politeknik Siber dan Sandi Negara
        """
        
        return EmailService.send_email(user_email, subject, body_html, body_text)
    
    
    @staticmethod
    def send_login_notification(user_email: str, full_name: str, ip_address: str, user_agent: str):
        """Notifikasi login dari perangkat baru"""
        subject = "Login Terdeteksi pada Akun Anda"
        
        body_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background-color: #3b82f6; color: white; padding: 20px; text-align: center; }}
                .content {{ padding: 20px; background-color: #f9fafb; }}
                .info-box {{ 
                    background-color: #e0f2fe; 
                    border-left: 4px solid #0284c7; 
                    padding: 15px; 
                    margin: 20px 0; 
                }}
                .footer {{ padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🔐 Login Terdeteksi</h1>
                </div>
                <div class="content">
                    <p>Halo <strong>{full_name}</strong>,</p>
                    
                    <p>Kami mendeteksi aktivitas login pada akun Anda:</p>
                    
                    <div class="info-box">
                        <p><strong>Waktu:</strong> {datetime.now().strftime('%d %B %Y, %H:%M:%S WIB')}</p>
                        <p><strong>IP Address:</strong> {ip_address}</p>
                        <p><strong>Browser/Device:</strong> {user_agent[:100]}</p>
                    </div>
                    
                    <p>Jika ini bukan Anda, segera:</p>
                    <ul>
                        <li>Ubah password Anda</li>
                        <li>Hubungi administrator sistem</li>
                    </ul>
                </div>
                <div class="footer">
                    <p>Email ini dikirim untuk keamanan akun Anda.</p>
                    <p>&copy; 2026 Politeknik Siber dan Sandi Negara.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return EmailService.send_email(user_email, subject, body_html)
