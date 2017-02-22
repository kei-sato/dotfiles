if test ! $(which spoof)
then
  sudo npm install spoof -g
fi

if test ! $(which tldr)
then
  npm install tldr -g
fi
