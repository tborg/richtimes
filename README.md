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

