pipeline {
    agent any
    stages {
        stage('Verify version file') {
            steps {
                dir('lesson1') {
                    sh 'test -s version.txt'
                    sh 'cat version.txt'
                }
            }
        }
    }
}
