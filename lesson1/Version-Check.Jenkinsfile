pipeline {
    agent any
    stages {
        stage('Verify version file') {
            steps {
                sh 'test -s version.txt'
                sh 'cat version.txt'
            }
        }
    }
}
