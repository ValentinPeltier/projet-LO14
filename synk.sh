#!/bin/bash

WORKING_DIRECTORY=~/.synk
LAST_SYNK=$WORKING_DIRECTORY/last
DEFAULT_SYNK_FILE=$WORKING_DIRECTORY/default-1.synk

# Create a synchronisation file between directories A and B at a specified path S
# B should be empty
# syntax : init A B S
function init {
    echo "Creating a synchronisation file..."
   
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

    # Get all files in A and B directories with a depth of 1
    files=$(echo -e "$(ls -A $1)\n$(ls -A $2)" | sort -u)

    # Processing with each file :
    for file in $files; do

        # Check if both are directories
        if [ -d $1/$file ] && [ -d $2/$file ]; then 
            echo $(synk $1/$file $2/$file $3)

        # Check if one is a directory and one is a file
        elif ([ -d $1/$file ] && [ ! -d $2/$file ]) || ([ ! -d $1/$file ] && [ -d $2/$file ]); then
            
            if [ -d $1/$file ]; then
                echo "Conflict: $1/$file is a directory $2/$file is not"
            else
                echo "Conflict: $2/$file is a directory $1/$file is not"
            fi
            flag=0
            while [ $flag = 0 ]; do

                echo "1) See whats is the difference"
                echo "2) Keep $1/$file and delete $2/$file"
                echo "3) Keep $2/$file and delete $1/$file"
                echo "4) Cancel synchronization"
                read choice

                case "$choice" in
                    1)
                    cat $1/$file
                    cat $2/$file
                    ;;
                    2)
                    rm $2/$file
                    if [ -f $1/$file ]; then
                        sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file)/'
                    fi
                    flag=1
                    ;;
                    3)
                    rm $1/$file
                    if [ -f $2/$file ]; then
                        sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file)/'
                    fi
                    flag=1
                    ;;
                    4)
                    exit;;
                    *)
                    echo "That is not an option"
                    sleep 3
                    ;;
                esac
            done

        
        else # Otherwise both are files

            # Check if metada are different
            if [ $(ls -l $1/$file) -ne $(ls -l $2/$file)]; then
                
                #Check if the first file is new or is the most recently modified
                if [ ( $(date -r $1/$file +%s) -ne $(date -r $3/$file +%s) && $(date -r $2/$file +%s) -eq $(date -r $(echo $3 | grep $file | awk '{FS="//" ; print $4} ') +%s) ) || ! ( -f $2/$file && $3 || grep $file -c -gt 1)];       
                    cat $1/$file > $2/$file;
                    # Check if .synk need to be modified or created
                    if [ $3 | grep $file -c -gt 1 ]; then
                        sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file)/'
                    elif
                        $(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file) >> $3;
                    fi

                elif [ ( $(date -r $2/$file +%s) -ne $(date -r $3/$file +%s) && $(date -r $1/$file +%s) -eq $(date -r $(echo $3 | grep $file | awk '{FS="//" ; print $4} ') +%s) || ! ( -f $1/$file && $3 || grep $file -c -gt 1)];
                    cat $2/$file > $1/$file;

                    if [ $3 | grep $file -c -gt 1 ]; then
                        sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file)/'
                    elif
                        $(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file) >> $3;
                    fi

                # Check if files need to be removed
                elif [! -f $1/$file && -f $3]; then
                    rm $2/$file;
                    rm $3 | grep $file;
                
                elif [! -f $1/$file && -f $3]; then
                    rm $1/$file;
                    rm $3 | grep $file;
                
                # Check if contents are similar
                elif [ cat $1/$file -eq cat $2/$file ]; then
                    echo "Error : file content are similar but metadata are not. Please choose one option"
                    flag=0
                    while [ $flag = 0 ]; do

                        echo "1) See what metada are"
                        echo "2) Keep  $1/$file and overwrite $2/$file"
                        echo "3) Keep $2/$file and overwrite $1/$file"
                        echo "4) Cancel synchronization"
                        read choice

                        case "$choice" in
                            1)
                            ls -l $2/$file
                            ls -l $1/$file
                            ;;
                            2)
                            cat $1/$file > $2/$file
                            sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file)/'
                            flag=1
                            ;;
                            3)
                            cat $2/$file > $1/$file
                            sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $2/$file)/'
                            flag=1
                            ;;
                            4)
                            exit;;
                            *)
                            echo "That is not an option"
                            sleep 3
                            ;;
                        esac
                    done
                    
                else
                    echo "Conflict : files are different, please choose one option" 
                    flag=0
                    while [ $flag = 0 ]; do
                    
                        echo "1) See what is the difference"
                        echo "2) Keep $1/$file and overwrite $2/$file"
                        echo "3) Keep $2/$file and overwrite $1/$file"
                        echo "4) Cancel synchronization"
                        read choice

                        case "$choice" in
                            1)
                            echo $1/$file
                            echo $2/$file
                            ;;
                            2)
                            cat $1/$file > $2/$file
                            sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $1/$file)/'
                            flag=1
                            ;;
                            3)
                            cat $2/$file $1/$file
                            sed 's/^$file/$(realpath --relative-to=$2 $1/$file)//$(stat -c '%A//%s//%y' $2/$file)/'
                            flag=1
                            ;;
                            4)
                            exit;;
                            *)
                            echo "That is not an option"
                            sleep 3
                            ;;
                        esac
                    done
                fi

            else
                echo "Files are similar : no need to synchronize"
            fi 
        fi

    done
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
            SYNK_FILE=$(realpath $1)
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
            SYNK_FILE=$(realpath $4)
        else
            SYNK_FILE=$DEFAULT_SYNK_FILE
        fi

        # Check if B exist and is not a directory, or if B is a directory that is not empty, then there is an error
        if ([ -e $3 ] && [ ! -d $3 ]) || ([ -d $3 ] && [ $(ls -A $3 | wc -w) -gt 0 ]); then
            fatalError "Error: the second directory must not exist or must be empty"
        fi

        # Get the absolute paths from the given paths
        A=$(realpath $2)
        B=$(realpath $3)
        
        # Initiate a synchronisation between directories A and B by creating a synk file at the specified path
        init $A $B $SYNK_FILE
        
        # Update the last-synk file so that we can remember the last synk file used
        setLastSynkFile $SYNK_FILE
        ;;

    * ) fatalError "Error: invalid arguments number"
        ;;
esac

exit 0
