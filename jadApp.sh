#/bin/bash
srcDir=$1
dstDir=$2

function usage {
echo "Usage: jadApp.sh srcDir dstDir"

}

if [ -z $srcDir ]; then
	usage
	exit 1
fi
if [ -z $dstDir ]; then
	usage
	exit 1
fi

Recursive=NO
if [ "$3" == "YES" ]; then
	Recursive="YES"
fi

which jad 2>&1 >/dev/null
if [ $? -ne 0 ]; then
	echo Error: jad not found. Download from http://varaneckas.com/jad, make executable, and copy to /usr/bin
	exit 2
fi

#start http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SCRIPT_PATH="${BASH_SOURCE[0]}";
if ([ -h "${SCRIPT_PATH}" ]) then
  while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi
pushd . > /dev/null
cd `dirname ${SCRIPT_PATH}` > /dev/null
SCRIPT_PATH=`pwd`;
popd  > /dev/null
#stop http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in

function fixAccessRights {

	where=$1

	echo -n "Fixing access rights"
	result=1
	while [ $result -ne 0 ]; do
	 find $where -type d -exec chmod +rwx {} + &>/dev/null
	 result=$?
	 echo -n .
	done
	echo Done.
}

for file in $(ls $srcDir); do 
	echo $srcDir/$file
	if [ -d $srcDir/$file ]; then
		echo Directory
		mkdir -p $dstDir/$srcDir
		#make directory recursive if cal to this level was recursive
		$SCRIPT_PATH/jadApp.sh $srcDir/$file $dstDir $Recursive
	elif [ -f $srcDir/$file ]; then
		echo File
		ext=$(echo "${file##*.}")
		echo $ext
		if [ $ext == "jar" ]; then
                        if [ $Recursive == "YES" ]; then
				echo RECURSIVE
				chmod +rw $dstDir$srcDir/$file
				mv $dstDir$srcDir/$file $dstDir$srcDir/_$file
				echo $dstDir$srcDir/$file
                                mkdir -p $dstDir$srcDir/$file
                                cd $dstDir$srcDir/$file
                                unzip -l $srcDir/_$file >files.txt
                                unzip -o -q $srcDir/_$file
				fixAccessRights $dstDir$srcDir/$file

				find . -name '*.class' -exec chmod +rw {} +
				find . -type d -execdir jad -o -sjava -d '{}' '{}/*.class' >>jad.log 2>&1 \;
                                #jad -o -r -sjava **/*.class 2>&1 | tee jad.log
				#find . -name '*.class' -exec rm -f {} +
                                cd -
				rm $dstDir$srcDir/_$file
			else
				mkdir -p $dstDir$srcDir/$file
				cd $dstDir$srcDir/$file
                                unzip -l $srcDir/$file >files.txt
				unzip -o -q $srcDir/$file
				fixAccessRights $dstDir$srcDir/$file

				find . -name '*.class' -exec chmod +rw {} +
				find . -type d -execdir jad -o -sjava -d '{}' '{}/*.class' >>jad.log 2>&1 \;
				#jad -o -r -sjava **/*.class 2>&1 | tee jad.log
				#find . -name '*.class' -exec rm -f {} +
				cd -
			fi
		elif [ $ext == "ear" ]; then
                        mkdir -p $dstDir$srcDir/$file
                        cd $dstDir$srcDir/$file
			unzip -l $srcDir/$file >files.txt
                        unzip -o -q $srcDir/$file
			fixAccessRights $dstDir$srcDir/$file
			cd -
			$SCRIPT_PATH/jadApp.sh $dstDir$srcDir/$file / YES
                elif [ $ext == "war" ]; then
			if [ $Recursive == "YES" ]; then
                                echo RECURSIVE
                                chmod +rw $dstDir$srcDir/$file
				mv $dstDir$srcDir/$file $dstDir$srcDir/_$file
				mkdir -p $dstDir$srcDir/$file
				cd $dstDir$srcDir/$file
                                unzip -l $srcDir/_$file >files.txt				
				unzip -o -q $srcDir/_$file
				fixAccessRights $dstDir$srcDir/$file
				cd -
				$SCRIPT_PATH/jadApp.sh $dstDir$srcDir/$file / YES 
				#rm $dstDir$srcDir/_$file
			else
                                mkdir -p $dstDir$srcDir/$file
                                cd $dstDir$srcDir/$file
			        unzip -l $srcDir/$file >files.txt
				unzip -o -q $srcDir/$file
				fixAccessRights $dstDir$srcDir/$file
                                cd -
                                $SCRIPT_PATH/jadApp.sh $dstDir$srcDir/$file / YES
			fi
                elif [ $ext == "rar" ]; then
                        if [ $Recursive == "YES" ]; then
                                echo RECURSIVE
                                chmod +rw $dstDir$srcDir/$file
                                mv $dstDir$srcDir/$file $dstDir$srcDir/_$file
                                mkdir -p $dstDir$srcDir/$file
                                cd $dstDir$srcDir/$file
                                unzip -l $srcDir/_$file >files.txt
				unzip -o -q $srcDir/_$file
				fixAccessRights $dstDir$srcDir/$file
                                cd -
                                $SCRIPT_PATH/jadApp.sh $dstDir$srcDir/$file /  YES
				#rm $dstDir$srcDir/_$file
                        else
                                mkdir -p $dstDir$srcDir/$file
                                cd $dstDir$srcDir/$file
                                unzip -l $srcDir/$file >files.txt
                                unzip -o -q $srcDir/$file
				fixAccessRights $dstDir$srcDir/$file
                                cd -
                                $SCRIPT_PATH/jadApp.sh $dstDir$srcDir/$file / YES
                        fi

                elif [ $ext == "mar" ]; then
                        if [ $Recursive == "YES" ]; then
                                echo RECURSIVE
                                chmod +rw $dstDir$srcDir/$file
                                mv $dstDir$srcDir/$file $dstDir$srcDir/_$file
                                mkdir -p $dstDir$srcDir/$file
                                cd $dstDir$srcDir/$file
                                unzip -l $srcDir/_$file >files.txt
                                unzip -o -q $srcDir/_$file
                                fixAccessRights $dstDir$srcDir/$file
                                cd -
                                $SCRIPT_PATH/jadApp.sh $dstDir$srcDir/$file /  YES
                                #rm $dstDir$srcDir/_$file
                        else
                                mkdir -p $dstDir$srcDir/$file
                                cd $dstDir$srcDir/$file
                                unzip -l $srcDir/$file >files.txt
                                unzip -o -q $srcDir/$file
                                fixAccessRights $dstDir$srcDir/$file
                                cd -
                                $SCRIPT_PATH/jadApp.sh $dstDir$srcDir/$file / YES
                        fi
		else
			mkdir -p $dstDir$srcDir
			cp $srcDir/$file $dstDir$srcDir
		fi 
	else
		echo Special
	fi
done

