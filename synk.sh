#!/bin/bash

DEFAULT_SYNK_FILE=~/.synk/default-1.synk

# Create a synchronisation file between directories A and B at a specified path S
# syntax : init A B S
function init {
    echo "init($1, $2, $3)"
}

# Synchronize directories A and B based on a synchronisation file S
# syntax : synk A B S
function synk {
    echo "synk($1, $2, $3)"
}

# Get the absolute path from an absolute path or a relative path P
# syntax : getAbsolutePath P
function getAbsolutePath {
    if [ $# -ne 1 ]; then
        return 1
    fi
    
    if [ ${1:0:1} = "/" ]; then
        echo $1
    else
        echo $(pwd)/$1
    fi
    return 0
}

# Display a message M to stderr (optional) and exit
# syntax : fatalError [M]
function fatalError {
    if [ $# -ge 1 ]; then
        >&2 echo $1
    fi

    exit 1
}

case $# in
    # Synchronize
    0 | 1)
        if [ $# -eq 0 ] && [ ! $SYNK_FILE ]; then
            SYNK_FILE=$DEFAULT_SYNK_FILE
        elif [ $# -eq 1 ]; then
            SYNK_FILE=$(getAbsolutePath $1)
        fi

        if [ ! -e $SYNK_FILE ]; then
            fatalError "Error: the synchronisation file does not exist"
        fi    
    
        if [ ! -w $SYNK_FILE ]; then
            fatalError "Error: cannot write to $SYNK_FILE: permission denied"
        fi

        # Get A and B from the synk file
        A=$(head -n 1 $SYNK_FILE)
        B=$(head -n 2 $SYNK_FILE | tail -n 1)

        synk $A $B $SYNK_FILE
        ;;

    # Initialize
    3 | 4 )
        if [ $1 != "init" ]; then
            fatalError "Error: invalid syntax"
        fi

        if [ $# -eq 3 ]; then
            SYNK_FILE=$DEFAULT_SYNK_FILE
        elif [ $# -eq 4 ]; then
            SYNK_FILE=$(getAbsolutePath $4)
        fi

        A=$(getAbsolutePath $2)
        B=$(getAbsolutePath $3)

        init $A $B $SYNK_FILE
        ;;

    * ) fatalError "Error: invalid arguments number"
        ;;
esac
