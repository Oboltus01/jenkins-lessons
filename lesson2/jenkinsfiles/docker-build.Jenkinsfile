pipeline {
    agent any

    stages {
        stage('Generate Files') {
            steps {
                writeFile file: 'app.py', text: '''
from http.server import HTTPServer, BaseHTTPRequestHandler

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(b"Jenkins Container Build Successful!")

HTTPServer(("", 8000), Handler).serve_forever()
'''
                writeFile file: 'Dockerfile', text: '''
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
EXPOSE 8000
CMD ["python", "app.py"]
'''
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t my-web-app:1 .'
            }
        }

        stage('Verify Image') {
            steps {
                sh 'docker images | grep my-web-app'
            }
        }

        stage('Test Container') {
            steps {
                sh '''
                    docker rm -f my-web-app-test 2>/dev/null || true
                    docker run -d --name my-web-app-test my-web-app:1
                    sleep 2
                    docker run --rm \
                      --network container:my-web-app-test \
                      curlimages/curl:8.10.1 \
                      -fsS http://localhost:8000
                    docker rm -f my-web-app-test
                '''
            }
        }
    }
}
