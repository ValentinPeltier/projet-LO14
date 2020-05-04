#!/bin/bash

WORKING_DIRECTORY=~/.synk
LAST_SYNK=$WORKING_DIRECTORY/last
DEFAULT_SYNK_FILE=$WORKING_DIRECTORY/default-1.synk

# Create a synchronisation file between directories A and B at a specified path S
# B should be empty
# syntax : init A B S
function init {
    echo -e "Creating a synchronisation file..."
   
    # Check if the synk file already exist
    if [ -e $3 ]; then
        fatalError "Error: $3 already exists"
    fi

    # Write A and B paths in S
    echo -e "$1\n$2" > $3

    # Append files stats
    echo -E "$(getStats $1 $1)" | tee -a $3 > /dev/null

    echo "Success: the synchronisation file has been created at $3"
}

# Synchronize directories A and B based on a synchronisation file S
# syntax : synk A B S
function synk {
    echo "synk($1, $2, $3)"
}

# Return files stats recursively in D
# The file names are relative to R
# syntax : getStats D R
function getStats {
    for file in $(ls -A $1); do
        if [ -d $1/$file ]; then
            echo $(getStats $1/$file $2)
        else
            echo "$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file)"
        fi
    done

    return 0
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
        echo $1 >&2
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

        # Check if the synk file exists
        if [ ! -e $SYNK_FILE ]; then
            fatalError "Error: the synchronisation file does not exist at the specified path ($SYNK_FILE)"
        fi    
        
        # Check if we can write to the synk file
        if [ ! -w $SYNK_FILE ]; then
            fatalError "Error: cannot write to $SYNK_FILE: permission denied"
        fi

        # Check if the synk file is a regular file
        if [ ! -f $SYNK_FILE ]; then
            fatalError "Error: you must specify a valid synchronisation file"
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
        # Check that the first argument is "init"
        if [ $1 != "init" ]; then
            fatalError "Error: unknown command \"$1\""
        fi

        # If the user has given a path for the synk file, then we use it, else we use the default path
        if [ $# -eq 4 ]; then
            SYNK_FILE=$(getAbsolutePath $4)
        else
            SYNK_FILE=$DEFAULT_SYNK_FILE
        fi

        # Check if B exist and is not a directory, or if B is a directory that is not empty, then there is an error
        if ([ -e $3 ] && [ ! -d $3 ]) || ([ -d $3 ] && [ $(ls -A $3 | wc -w) -gt 0 ]); then
            fatalError "Error: the second directory must not exist or must be empty"
        fi

        # If the second directory does not exist, then we create it
        mkdir $3 2>/dev/null

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

exit 0
