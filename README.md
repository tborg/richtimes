This app expands the possibilities for interaction with the Richmond Times Dispatch collection of civil-war era newspapers hosted at the [Perseus Project](http://www.perseus.tufts.edu/hopper/collection?collection=Perseus:collection:RichTimes)

To get started:

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
# Launch the app
grunt server
```

You'll also need to [download the texts from Perseus](http://www.perseus.tufts.edu/hopper/opensource/download) and copy them into a directory called `xml` in the root of your app (or configure a different directory.)