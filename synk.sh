#!/bin/bash

WORKING_DIRECTORY=~/.synk
LAST_SYNK=$WORKING_DIRECTORY/last
DEFAULT_SYNK_FILE=$WORKING_DIRECTORY/default-1.synk

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

# Store a synk file S in the last-synk file
# syntax : updateLastSynkFile S
function setLastSynkFile {
    if [ $# -eq 1 ]; then
        echo $1 > $LAST_SYNK
    fi
    return 1
}

# Return the last-synk file path
# syntax : getLastSynkFile
function getLastSynkFile {
    if [ ! -r $LAST_SYNK ]; then
        return 1
    fi

    cat $LAST_SYNK
    return 0
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

#####################################################
#####################################################
#####################################################

# Create working directory
mkdir -p $WORKING_DIRECTORY

# Retrieve the last-synk file
SYNK_FILE=$(getLastSynkFile)

case $# in
    # Synchronize
    0 | 1)
        # synk --> check if a synchronisation has been initiated
        if [ $# -eq 0 ] && [ ! $SYNK_FILE ]; then
           fatalError "Error: please initiate a synchronisation first" 
        fi
        
        # synk S --> set the synk file path with the path given by the user
        if [ $# -eq 1 ]; then
            SYNK_FILE=$(getAbsolutePath $1)
        fi

        # check if the synk file exists
        if [ ! -e $SYNK_FILE ]; then
            fatalError "Error: the synchronisation file does not exist at the specified path ($SYNK_FILE)"
        fi    
        
        # check if we can write to the synk file
        if [ ! -w $SYNK_FILE ]; then
            fatalError "Error: cannot write to $SYNK_FILE: permission denied"
        fi

        # Get A and B paths from the synk file
        A=$(head -n 1 $SYNK_FILE)
        B=$(head -n 2 $SYNK_FILE | tail -n 1)

        # Synchronise directories A and B with the specified synk file
        synk $A $B $SYNK_FILE

        # Update the last-synk file so that we can remember the last synk file used
        setLastSynkFile $SYNK_FILE
        ;;

    # Initialize
    3 | 4 )
        # check that the first argument is "init"
        if [ $1 != "init" ]; then
            fatalError "Error: unknown command \"$1\""
        fi

        # if the user has given a path for the synk file, then we use it, else we use the default path
        if [ $# -eq 4 ]; then
            SYNK_FILE=$(getAbsolutePath $4)
        else
            SYNK_FILE=$DEFAULT_SYNK_FILE
        fi

        # Get the absolute paths from the given paths
        A=$(getAbsolutePath $2)
        B=$(getAbsolutePath $3)

        # Initiate a synchronisation between directories A and B by creating a synk file at the specified path
        init $A $B $SYNK_FILE
        
        # Update the last-synk file so that we can remember the last synk file used
        setLastSynkFile $SYNK_FILE
        ;;

    * ) fatalError "Error: invalid arguments number"
        ;;
esac
