pipeline {
    agent any
    stages {
        stage('Checkout & Verification') {
            steps {
                echo 'Checking workspace directory...'
                sh 'ls -la'
            }
        }
        stage('Test App') {
            steps {
                echo 'Simulating test execution on code pulled from Git...'
                sh 'echo "Code tests passed successfully!"'
            }
        }
    }
}
