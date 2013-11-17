from fabric.api import run, env

env.hosts = ['tborg@linode1.cs.luc.edu']

def deploy_latest():
    run('source env/bin/activate')
    run('source .bash_aliases')
    run('cd richtimes_checkout')
    run('git pull origin master')
    run('grunt')
    run('rm -rf ../richtimes')
    run('cp -r ./dist ../richtimes')
    run('cd ../')
    run('supervisorctl -c ./richtimes/supervisord.conf')
