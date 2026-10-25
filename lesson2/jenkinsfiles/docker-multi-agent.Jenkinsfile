pipeline {
    agent none

    stages {
        stage('Node.js Test') {
            agent {
                docker {
                    image 'node:20-alpine'
                }
            }
            steps {
                sh 'node --version'
                sh 'npm --version'
            }
        }

        stage('Python Test') {
            agent {
                docker {
                    image 'python:3.11-slim'
                }
            }
            steps {
                sh 'python --version'
                sh 'pip --version'
            }
        }
    }
}
