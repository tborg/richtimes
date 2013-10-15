from richtimes import app
from richtimes.scripts.shell import make_shell_context, Rebuild
from flask.ext.script import Manager, Shell

manager = Manager(app)
manager.add_command('shell', Shell(make_context=make_shell_context))
manager.add_command('rebuild', Rebuild())

if __name__ == '__main__':
    manager.run()
