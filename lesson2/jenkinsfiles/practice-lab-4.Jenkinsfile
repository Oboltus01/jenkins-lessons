pipeline {
    agent {
        docker {
            image 'alpine:latest'
        }
    }

    stages {
        stage('Create Artifact') {
            steps {
                sh 'echo "Build completed successfully" > build.log'
                sh 'cat build.log'

                archiveArtifacts artifacts: 'build.log', fingerprint: true
            }
        }
    }
}
