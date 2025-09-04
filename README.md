### pyact
This is a poor man's conda, but so much less annoying. 

Bash function gives you 
```
> # Switching to a python pyenv of version e.g. 3.9 and create a venv
> pyact -c 3.9
> # Activates the pyenv and venv of the respecive version.
> pyact 3.9
> # This checks if pyenv for python 3.9 is installed and if yes it actives it and sources the venv in this directory.
> # if you run pyact wihtout a version, it checks the largest that you have created in this directory and activates it.
> # If none is found, it goes up one directory and checks again (until $HOME).
# Now: 
(venv-python3.9) > pip install whatever # now you can pip install whatever.
(venv-python3.9) > python main.py # and use python as expected
(venv-python3.9) > pydeact # to get out of the mess again
> # and the best:
> rm venv-python3.9 # and its gone.
```
This way I dont have to deal with conda and it nesting into my bashrc etc. or expecting something that does not hold for every system.  
Additionally you can have different version and easily switch between them.

Prerequisites:   
pyenv and  
pyact.sh's content in your .bashrc or .bash_functions.  
