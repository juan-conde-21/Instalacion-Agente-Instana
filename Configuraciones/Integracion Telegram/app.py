from flask import Flask, request
import requests
import os

app = Flask(__name__)

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')

def format_message(data):
    issue = data.get('issue', {})
    message = "Nuevo evento de Instana:\n\n"
    for key, value in issue.items():
        message += f"{key.replace('_', ' ').capitalize()}: {value}\n"
    return message

def send_telegram_message(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        'chat_id': TELEGRAM_CHAT_ID,
        'text': message
    }
    requests.post(url, json=payload)

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    message = format_message(data)
    send_telegram_message(message)
    return '', 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
