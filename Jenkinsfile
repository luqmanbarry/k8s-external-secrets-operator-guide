pipeline {
    agent {
        node {
            label 'centos-large'
        }
    }

    parameters {
        string(name: 'gitBranch', defaultValue: 'develop', description: 'The Git branch to checkout from.', trim: true)
        string(name: 'ocTokenCredentialsId', defaultValue: 'ocp-tst-jenkins-eia', description: 'Token used by the OpenShift CLI to authenticate.', trim: true)
        string(name: 'awsCredentialsId', defaultValue: 'ocp-mvp-aws-eia', description: 'AWS ACCESS_KEY and SECRET_ACCESS_KEY details.', trim: true)
        string(name: 'targetNamespace', defaultValue: 'eia-dev-02', description: 'The target namespace to deploy the monitoring resources.', trim: true)
        string(name: 'operatorChartName', defaultValue: 'eso-deployment-resources', description: 'The chart name of the Operator.', trim: true)
        booleanParam(name: 'esoOperatorInstalled', defaultValue: false, description: 'Whether ESO Operator is available or not.')
        string(name: 'secretSyncChartName', defaultValue: 'eso-sync-resources', description: 'The chart name of the Sync resources.', trim: true)
        string(name: 'operatorValuesFile', defaultValue: 'charts/eso-deployment-resources/values.yaml', description: 'The vavlues file to use. Specify values in a YAML file or a URL (can specify multiple)', trim: true)
        string(name: 'secretSyncValuesFile', defaultValue: 'charts/eso-sync-resources/values.yaml', description: 'The vavlues file to use. Specify values in a YAML file or a URL (can specify multiple)', trim: true)
    }

    options {
        timeout(time: 30, unit: 'MINUTES') 
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20', daysToKeepStr: '30'))
        disableConcurrentBuilds()
        disableResume()
    }

    stages {
        stage("Verify Tools") {
            steps {
                sh ' echo "  Verying required tools are installed  " '
                sh '  echo "Verify HELM is installed." '
                sh '''
                    if ! helm version | grep 'v3'
                    then
                        echo "Helm v3.x could not be found."
                        exit -1
                    fi
                '''
                sh ' echo "  Verify OpenShift cli is installed.    " '
                sh '''
                    if ! oc version | grep 'Client Version: 4'
                    then
                        echo "oc cli v4.x could not be found."
                        exit -1
                    fi
                '''
            }
        }
        stage("Install Chart") {
            environment { 
                OCP_LOGIN                         = credentials("${params.ocTokenCredentialsId}")
                AWS_LOGIN                         = credentials("${params.awsCredentialsId}")
                NAMESPACE                         = "${params.targetNamespace}"
                OPERATOR_CHART_NAME               = "${params.operatorChartName}"
                ESO_OPERATOR_INSTALLED            = "${params.esoOperatorInstalled}"
                SEECRET_SYNC_CHART_NAME           = "${params.secretSyncChartName}"
                OPERATOR_VALUES_FILE              = "${params.operatorValuesFile}"
                SECRET_SYNC_VALUES_FILE           = "${params.secretSyncValuesFile}"
            }
            steps {
                timeout(time: 25, unit: 'MINUTES') {
                    sh ' echo "    Installing the helm chart...        " '
                    sh ' oc login "${OCP_LOGIN_USR}" --token "${OCP_LOGIN_PSW}" '
                    sh ' oc project ${NAMESPACE} '
                    retry(3) {

                        script {
                            if ( env.ESO_OPERATOR_INSTALLED == 'false' ) {

                                 sh '''
                                
                                    ESO_OPERATOR_CONFIGS="$(oc get operatorconfig -o name | grep eso || true)"
                                    if [ -z "$ESO_OPERATOR_CONFIGS" ];
                                    then
                                        echo "No OperatorConfig found..."
                                    else
                                        for ocg in "$ESO_OPERATOR_CONFIGS"; do oc delete $ocg; done;
                                    fi

                                    sleep 30
                                    
                                    helm upgrade --install ${OPERATOR_CHART_NAME} ./charts/eso-deployment-resources \
                                        -f ${OPERATOR_VALUES_FILE} \
                                        -n ${NAMESPACE}
                                    
                                    sleep 120
                                    
                                    helm upgrade --install ${SEECRET_SYNC_CHART_NAME} ./charts/eso-sync-resources \
                                        --set provider.aws.accessKey="${AWS_LOGIN_USR}" \
                                        --set provider.aws.secretAccessKey="${AWS_LOGIN_PSW}" \
                                        -f ${SECRET_SYNC_VALUES_FILE} \
                                        -n ${NAMESPACE}

                                    sleep 30
                                    
                                '''

                            } else {

                                sh '''
                                    
                                    helm upgrade --install ${SEECRET_SYNC_CHART_NAME} ./charts/eso-sync-resources \
                                        --set provider.aws.accessKey="${AWS_LOGIN_USR}" \
                                        --set provider.aws.secretAccessKey="${AWS_LOGIN_PSW}" \
                                        -f ${SECRET_SYNC_VALUES_FILE} \
                                        -n ${NAMESPACE}

                                    sleep 30

                                '''
                            }
                        }

                    }
                }
            }
        }
        stage("Verify Installation") {
            environment { 
                OPERATOR_CHART_NAME               = "${params.operatorChartName}"
                SEECRET_SYNC_CHART_NAME           = "${params.secretSyncChartName}"
                NAMESPACE                         =  "${params.targetNamespace}"
            }
            steps {
                retry(3) {
                    sh 'echo "Post installation validation..."'
                    sleep 60
                    sh '''
                        # Operator Chart
                        if ! helm history ${OPERATOR_CHART_NAME}
                        then
                            echo "Chart installation failed."
                            exit -1
                        fi
                        if [ "$(oc get po -n ${NAMESPACE} | grep Running | wc -l)" -gt "0" ];
                        then
                            echo "$$$$> ESO resources installation successful."
                        else
                            echo "&&&&> Required ESO Pods are down. Troubleshoot using the CLI and Web Console"
                            exit -1
                        fi

                        # Secret Sync Chart
                        if ! helm history ${SEECRET_SYNC_CHART_NAME}
                        then
                            echo "Chart installation failed."
                            exit -1
                        fi
                        if [ "$(oc get po -n ${NAMESPACE} | grep Running | wc -l)" -gt "0" ];
                        then
                            echo "$$$$> Secret Sync resources installation successful."
                        else
                            echo "&&&&> Required Secret Sync Pods are down. Troubleshoot using the CLI and Web Console"
                            exit -1
                        fi
                    '''
                    sh 'echo "====> BEGIN: Listing Installed resources "'
                    sh 'oc get operatorgroup,subscription,SecretStore,ExternalSecret,all'
                    sh 'echo "====> END: Listing Installed resources "'
                }
            }
        }
    }
    post {
        always {
            echo "Terminating OCP user session..."
            sh 'oc logout &> /dev/null'
            deleteDir()
        }
    }
}