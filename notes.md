




b8:27:eb:4f:71:11 power 1
b8:27:eb:4f:71:11 play
b8:27:eb:4f:71:11 pause

## Play an Album
echo "b8:27:eb:4f:71:11 playlist play /music/Prince/1999%20(1982)/" | nc sahmaxi 9090
b8:27:eb:4f:71:11 playlist play /music/Prince/Prince%20(1979)/

## Play a Dynamic Playlist

b8:27:eb:4f:71:11 dynamicplaylist playlist play dplccustom_play_year dynamicplaylist_parameter_1:2010

b8:27:eb:4f:71:11 dynamicplaylist playlist play dplccustom_play_year dynamicplaylist_parameter_1:2011

b8:27:eb:4f:71:11 dynamicplaylist playlist play dplccustom_2013
b8:27:eb:4f:71:11 dynamicplaylist playlist play dplccustom_2014

b8:27:eb:4f:71:11 stop
b8:27:eb:4f:71:11 playlist stop


b8:27:eb:4f:71:11 playlist index ?
