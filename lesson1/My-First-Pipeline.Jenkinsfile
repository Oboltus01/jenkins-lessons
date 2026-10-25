pipeline {
    agent any

    stages {
        stage('Compile') {
            steps {
                echo 'Compiling source code...'
                sh 'echo "Simulating code compilation complete."'
            }
        }
        stage('Test') {
            steps {
                echo 'Running automated tests...'
                sh 'echo "All 15 tests passed!"'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                sh 'echo "App successfully deployed to Staging!"'
            }
        }
    }
}
