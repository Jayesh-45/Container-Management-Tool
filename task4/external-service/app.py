from flask import Flask
import requests
import sys

# Update this variable as per your setup
COUNTER_SERVICE_URL = 'http://192.168.2.2:8080' if len(sys.argv) == 1 else sys.argv[1]

app = Flask(__name__)

@app.route('/')
def hello_world():
    res = requests.get(COUNTER_SERVICE_URL + '/get_and_increment_counter')
    return 'Hello CS695 Explorers! You have sent request to this container ' + res.text + ' times.'


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
