This app expands the possibilities for interaction with the Richmond Times Dispatch collection of civil-war era newspapers hosted at the [Perseus Project](http://www.perseus.tufts.edu/hopper/collection?collection=Perseus:collection:RichTimes)

### Setup

To get started:

You must define your own local config in the `server` directory and sym-link it
to config.py:

```bash
cd 
# copy an existing config
cp config_tborglocal.py config_<myname>local.py

# edit it to your liking
vi config_<myname>local.py

# symbolically link it to config.py
ln -s config_<myname>local.py config.py
```

You will need to [download the texts from Perseus](http://www.perseus.tufts.edu/hopper/opensource/download) and copy them into a directory called `xml` in the root of your app (or configure a different directory.)

You will also need to ensure that some kind of SQL database is running in your
environment, and set up your local config to use it.

Once you've downloaded those files and put them in your XML dir, follow these
commands:

```bash
# Create a new virtualenv
virtualenv env

# Activate it
source env/bin/activate

# Install python deps
pip install -r requirements.txt

# Install node deps
npm install

# Install client js deps
bower install

# Rebuild the index over the xml files
python server/manage.py rebuild

# Now you're ready to launch the webapp!
grunt server
```

Navigate your browser to [http://localhost:5000/](http://localhost:5000/)

## Deploy

These instructions were written against `Ubuntu 12.04.4 LTS (GNU/Linux 3.12.9-x86_64-linode37 x86_64)`.

_TODO_: I've started to automate this process in `fabfile.py`. It's not ready. It might be worthwhile to investigate [docker](https://www.docker.io/), a linux container engine.

### Initialize the server environment

This process installs the web app at `richtimes`, and adds an Upstart init
script which will launch the server on reboot.

The init script monitors a supervisord process configured in `~/richtimes/supervisord.conf`.
This supervisord config in turn launches and monitors some gunicorn threads which serve
the web app on port 5001.

```bash
# In the home directory of the app user
cd ~

# Create a virtual env.
virtualenv env

# Activate it
source env/bin/activate

# Clone the repo
git clone https://github.com/tborg/richtimes.git richtimes_checkout
cd ./richtimes_checkout

# Install dependencies (you can skip bower).
pip install -r requirements.txt
npm install

# Copy the upstart init config for the application. This starts and respawns supervisord on boot.
sudo cp ./server/richtimes/richtimes-supervisor.conf /etc/init/

# configure apache
sudo cp ./server/richtimes.ctsdh.luc.edu /etc/apache2/sites-available

# Build the distribution and lift it out of the checkout
grunt
cp -r dist ../richtimes

# Fill in the environment variables
cd ~
vi ./.bash_aliases

cd richtimes

# link the static files to your web space
ln -s ./htdocs /var/www/vhosts/richtimes.ctsdh.luc.edu/htdocs

# kick-start the Upstart launcher
sudo start richtimes-supervisor.conf # -> richtimes-supervisor start/running, process 6553

# confirm the server is running. 
supervisorctl # -> richtimes-server                 RUNNING    pid 6561, uptime 0:00:03
```

### Updating the deploy

You've made some changes to the app and you want to update production version.

```
cd ~/richtimes_checkout
git pull origin master
grunt
rm -rf ../richtimes
cp -r ./dist ../richtimes
sudo restart richtimes-supervisor
```