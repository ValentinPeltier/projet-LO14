#!/bin/bash

WORKING_DIRECTORY=~/.synk
LAST_SYNKFILE=$WORKING_DIRECTORY/last
DEFAULT_SYNKFILE=$WORKING_DIRECTORY/default-1.synk

# Create a synchronisation file between directories $A and $B at path $SYNKFILE
# $B should be empty
# syntax : init
function init {
    echo "Creating a synchronisation file..."

    # Check if the synk file already exist
    if [ -e $SYNKFILE ]; then
        fatalError "Error: $SYNKFILE already exists"
    fi

    # Synchronize the directories
    cp -r --preserve=all $A/* $B 2>/dev/null

    # Write A and B paths in S
    echo -e "$A\n$B" > $SYNKFILE

    # Append files metadata
    echo -E "$(getRecursiveMetadata $A $A)" | tee -a $SYNKFILE >/dev/null

    echo "Success: the synchronisation file has been created at $SYNKFILE"
}

# Synchronize directories D1 and D2 based on synchronisation file $SYNKFILE
# using the base paths $A and $B
# syntax : synk D1 D2
function synk {

    # Get all files in D1 and D2 directories with a depth of 1
    filenames=$(echo -e "$(ls -A $1 2>/dev/null)\n$(ls -A $2 2>/dev/null)" | sort -u)

    # Processing with each file
    for filename in $filenames; do

        # We retrieve the relative path
        file=$(realpath --relative-to=$A $1/$filename 2>/dev/null) || $(realpath --relative-to=$B $2/$filename)

        # Get retrieve the last synk/modified dates
        lastSynkDate=$(grep "^$file//" $SYNKFILE | awk -F '//' '{print $4}')
        modifiedDateA=$(stat -c '%Y' $A/$file 2>/dev/null)
        modifiedDateB=$(stat -c '%Y' $B/$file 2>/dev/null)

        # Example values :
        # $A = /path/to/dir/a
        # $B = /path/to/dir/b
        # $1 = /path/to/dir/a/path/to/target
        # $2 = /path/to/dir/b/path/to/target
        # $file = path/to/target/file.txt
        # $filename = file.txt
        #
        # $file is what we call "relative path"
        # $A/$file or $B/$file is what we call "absolute path"

        # If one is a directory and one is a file
        if ([ -d $A/$file ] && [ -f $B/$file ]) || ([ -f $A/$file ] && [ -d $B/$file ]); then

            # Display conflict message
            if [ -d $A/$file ]; then
                echo "Conflict: $file is a directory in $A but a file in $B"
            else
                echo "Conflict: $file is a directory in $B but a file in $A"
            fi

            resolveConflict $file

        # If at least one is a directory
        elif [ -d $A/$file ] || [ -d $B/$file ]; then

            # Use recursivity 
            synk $A/$file $B/$file

        # If file A does not exist but is in the synk file (then the file has been deleted)
        elif [ ! -e $A/$file ] && $(isInSynkFile $file); then

            # We delete it in B
            rm -f $B/$file
            # We remove it in the synk file
            sed -i "\~^$file//~d" $SYNKFILE

        # If file B does not exist but is in the synk file (then the file has been deleted)
        elif [ ! -e $B/$file ] && $(isInSynkFile $file); then

            # We delete it in A
            rm -f $A/$file
            # We remove it in the synk file
            sed -i "\~^$file//~d" $SYNKFILE

        # If metadata are identical
        elif [ "$(getFileMetadata $A/$file $file)" = "$(getFileMetadata $B/$file $file)" ]; then

            # Do nothing
            continue

        # If file A has been modified or created
        elif ([ -f $A/$file ] && [ "$modifiedDateA" != "$lastSynkDate" ] && [ "$modifiedDateB" = "$lastSynkDate" ]) || ([ ! -e $B/$file ] && ! $(isInSynkFile $file)); then

            # Overwrite old file with the new file
            mkdir -p $2 2>/dev/null
            cp -f --preserve=all $A/$file $B/$file
            
            # Update synk file with the new metadata
            updateSynkFile $A/$file $file

        # If file B has been modified or created
        elif ([ -f $B/$file ] && [ "$modifiedDateB" != "$lastSynkDate" ] && [ "$modifiedDateA" = "$lastSynkDate" ]) || ([ ! -e $B/$file ] && ! $(isInSynkFile $file)); then
            
            # Overwrite old file with the new file
            mkdir -p $1 2>/dev/null
            cp -f --preserve=all $B/$file $A/$file
            
            # Update synk file with the new metadata
            updateSynkFile $B/$file $file

        # If file contents are identical (then only metadata are different)
        elif $(cmp -s $A/$file $B/$file); then

            # Display conflict message
            echo "Conflict: metadata are different for file $file"
            echo -e "In $A\n\tPermissions: $(stat -c '%A' $A/$file)\n\tLast modified date: $(stat -c '%y' $A/$file)"
            echo -e "In $B\n\tPermissions: $(stat -c '%A' $B/$file)\n\tLast modified date: $(stat -c '%y' $B/$file)"

            resolveConflict $file

        # Otherwise it is a conflict
        else

            # Display conflict message
            echo "Conflict: $file has been modified in both directories"

            resolveConflict $file true

        fi
    done
}

# Return the metadata of the file with absolute path A and relative path R
# syntax : getFileMetadata A R
function getFileMetadata {
    if [ -f $1 ]; then
        echo "$2//$(stat -c '%A//%s//%Y' $1)"
        return 0
    fi

    return 1
}

# Return metadata of all files in directory D, relatively to a directory R
# syntax : getRecursiveMetadata D R
function getRecursiveMetadata {
    for filename in $(ls -A $1); do
        if [ -d $1/$filename ]; then
            echo "$(getRecursiveMetadata $1/$filename $2)"
        else
            echo "$(getFileMetadata $1/$filename $(realpath --relative-to=$2 $1/$filename))"
        fi
    done

    return 0
}

# Indicate if the file with relative path R is in the synchronization file $SYNKFILE
# syntax: isInSynkFile R
function isInSynkFile {
    [ $(grep "^$1//" $SYNKFILE -c) -gt 0 ] && echo true || echo false
    return 0
}

# Update the metadata in the synchronization file $SYNKFILE
# for the file with absolute path A and relative path R
# syntax: updateSynkFile A R
function updateSynkFile {
    # If file is in the synk file
    if $(isInSynkFile $2); then
        # We update its metadata in the synk file
        # We use tildes as delimiters beacause slashs don't work since it is used in the filenames
        sed -i "s~^$2//.*~$(getFileMetadata $1 $2)~g" $SYNKFILE
    else
        # We add it to the synk file
        getFileMetadata $1 $2 >> $SYNKFILE
    fi
}

# Ask the user to resolve the conflict for the file with relative path R
# with possibility to display the difference if D equals "true"
# syntax: resolveConflict R [D]
function resolveConflict {
    # Loop until the user resolve the conflict
    while :; do
        echo -e "\t1) Keep $1 in $A"
        echo -e "\t2) Keep $1 in $B"
        [ "$2" = true ] && echo -e "\t3) Display difference"
        echo -e "\t0) Skip"
        echo -en "\t> "
        read choice

        case $choice in
        1)
            # Overwrite the selected file or directory
            rm -rf $B/$1
            cp -r --preserve=all $A/$1 $(dirname $B/$1)

            # Update the synk file with the new metadata
            updateSynkFile $A/$1 $1

            break
            ;;
        2)
            # Overwrite the selected file or directory
            rm -rf $A/$1
            cp -r --preserve=all $B/$1 $(dirname $A/$1)

            # Update the synk file with the new metadata
            updateSynkFile $B/$1 $1

            break
            ;;
        3)
            if [ "$2" != true ]; then
                echo -e "Invalid option\n"
                continue
            fi

            # Display the difference
            echo -e "$A/$1\t| $B/$1\n\n$(diff -y $A/$1 $B/$1)" | less
            ;;

        0) break ;;
        *) echo -e "Invalid option\n" ;;
        esac
    done
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

# Get options
VERBOSE=

OPTS=$(getopt -o vh -l verbose,help -- "$@")
if [ "$?" != 0 ]; then
    exit 1
fi
eval set -- "$OPTS"

while true; do
    case "$1" in
    -h | --help)
        echo "usage: synk [OPTION]... [init DIRECTORY_A DIRECTORY_B] [SYNK_PATH]"
        exit 0
        ;;
    -v | --verbose)
        VERBOSE=true
        shift
        ;;
    --) break ;;
    esac
done
# Skip the -- option
shift

# Create working directory
mkdir -p $WORKING_DIRECTORY

# Retrieve the last-synk file
SYNKFILE=$(cat $LAST_SYNKFILE 2>/dev/null)

case $# in
# Synchronize
0 | 1)
    # synk --> check if a synchronisation has been initiated
    if [ $# -eq 0 ] && [ ! $SYNKFILE ]; then
        fatalError "Error: please initiate a synchronisation first or check $LAST_SYNKFILE"
    fi

    # synk S --> set the synk file path with the path given by the user
    if [ $# -eq 1 ]; then
        SYNKFILE=$(realpath $1)
    fi

    # Check if the synk file exists
    if [ ! -e $SYNKFILE ]; then
        fatalError "Error: the synchronisation file does not exist at the specified path ($SYNKFILE)"
    fi

    # Check if we can write to the synk file
    if [ ! -w $SYNKFILE ]; then
        fatalError "Error: cannot write to $SYNKFILE: permission denied"
    fi

    # Check if the synk file is a regular file
    if [ ! -f $SYNKFILE ]; then
        fatalError "Error: you must specify a valid synchronisation file"
    fi

    # Get A and B paths from the synk file
    A=$(head -n 1 $SYNKFILE)
    B=$(head -n 2 $SYNKFILE | tail -n 1)

    # Synchronise directories A and B with the specified synk file
    synk $A $B

    echo "Files synchronized successfully"

    # Update the last-synk file so that we can remember the last synk file used
    echo $SYNKFILE > $LAST_SYNKFILE
    ;;

# Initialize
3 | 4)
    # Check that the first argument is "init"
    if [ $1 != "init" ]; then
        fatalError "Error: unknown command \"$1\""
    fi

    # If the user has given a path for the synk file, then we use it, else we use the default path
    if [ $# -eq 4 ]; then
        SYNKFILE=$(realpath $4)
    else
        SYNKFILE=$DEFAULT_SYNKFILE
    fi

    # Check if B exist and is not a directory, or if B is a directory that is not empty, then there is an error
    if ([ -e $3 ] && [ ! -d $3 ]) || ([ -d $3 ] && [ $(ls -A $3 | wc -w) -gt 0 ]); then
        fatalError "Error: the second directory must not exist or must be empty"
    fi

    # Create B directory if needed
    mkdir -p $3

    # Get the absolute paths from the given paths
    A=$(realpath $2)
    B=$(realpath $3)

    # Initiate a synchronisation between directories A and B by creating a synk file S
    init

    # Update the last-synk file so that we can remember the last synk file used
    echo $SYNKFILE > $LAST_SYNKFILE
    ;;

*)
    fatalError "Error: invalid arguments number"
    ;;
esac

exit 0
