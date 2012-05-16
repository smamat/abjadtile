#!/bin/sh

# position of letter single, front, middle, end
pos=0

yalign=0.5
isGridOn=0

while getopts ":01234y:g" opt; do
	case $opt in
		0) 
			pos=0
			;;
		1)
			pos=1
			;;
		2)
			pos=2
			;;
		3)
			pos=3
			;;
		4)
			pos=4
			;;
		y)
#			echo "setting y-coordinate alignment to $OPTARG"
			yalign=$OPTARG
			;;
		g)
			isGridOn=1
			;;
		\?)
			echo "-> ERR: invalid option: -$OPTARG" >&2
			;;
		\:)
			echo "-> ERR: argument to $OPTARG empty" >&2
	esac
done

#echo "OPTIND is $OPTIND"
shift $((OPTIND-1))
#echo "first argument now is $1"

# letter name and string
fname=$1$pos
str=$2
if [ -z $1 ] 
	then
		str=ki--yi
		fname=ki$pos
#		echo "-> making \"$str\", file ${fname}.eps"
	else
		if [ -z $2 ]
			then
				str=ki--yi
				fname=$1$pos
		fi
fi
		

# which letter position?
case $pos in
	0)
		echo "-> single letter untrimmed"
		;;
	1)
		echo "-> single letter trimmed"
		;;
	2)
		echo "-> front letter trimmed"
		;;
	3)
		echo "-> middle letter trimmed"
		;;
	4)
		echo "-> rear letter trimmed"
		;;
esac

# y-coord alignment
echo "-> y-coordinate alignment is $yalign"

echo "-> making \"$str\" in file ${fname}.eps"

# letter file
lfile=_$fname
echo "-> processing letter file: $lfile.tex"


cat >${lfile}.tex <<EOF
\documentclass[12pt]{article}
\usepackage{pstricks}
\usepackage{arabtex}
\pagestyle{empty}
\begin{document}
\setmalay
\novocalize
\Huge
{\RL{${2}}}
\end{document}
EOF

latex $lfile >/dev/null
dvips $lfile -E -o ${lfile}.eps >/dev/null 2>/dev/null
epstool --copy --bbox ${lfile}.eps temp.eps >/dev/null
mv temp.eps ${lfile}.eps
for i in aux log dvi tex
	do rm ${lfile}.${i}
done

# sfile or scaled file
sfile=_${fname}_s
echo "-> processing scaled file: ${sfile}.tex"

cat >${sfile}.tex <<EOF
\documentclass[12pt]{article}
\usepackage{pstricks,pst-eps,graphicx}
\pagestyle{empty}
\begin{document}
\begin{TeXtoEPS}
\psset{xunit=75px,yunit=75px}
\begin{pspicture}(0,0)(1,1)
\rput(0.5,0.5){\includegraphics[scale=2.0]{${lfile}.eps}}
\end{pspicture}
\end{TeXtoEPS}
\end{document}
EOF

latex $sfile >/dev/null
dvips $sfile -E -o ${sfile}.eps >/dev/null 2>/dev/null
epstool --copy --bbox ${sfile}.eps temp.eps >/dev/null #2>/dev/null
mv temp.eps ${sfile}.eps
for i in aux log dvi tex
	do rm ${sfile}.${i}
done
rm $lfile.eps

#############################################
# Find BoundingBox llx lly urx ury in sfile #
#############################################

echo "-> finding boundingbox of $sfile.eps"
bbparam=`sed -n '/%%BoundingBox/{p;q;}' $sfile.eps`
hbbparam=`sed -n '/%%HiResBoundingBox/{p;q;}' $sfile.eps`

export IFS=" "

i=0;
for word in $bbparam;
	do bb[i]=$word
#	echo "$i: ${bb[i]}"
	let i=i+1
done
llx=${bb[1]}
lly=${bb[2]}
urx=${bb[3]}
ury=${bb[4]}

i=0;
for word in $hbbparam;
	do bb[i]=$word
#	echo "$i: ${bb[i]}"
	let i=i+1
done
hllx=${bb[1]}
hlly=${bb[2]}
hurx=${bb[3]}
hury=${bb[4]}

echo "-> BoundingBox parameters for $sfile.eps are $llx $lly $urx $ury"
echo "-> HiResBoundingBox parameters for $sfile.eps are $hllx $hlly $hurx $hury"


######################################################
# make tile file (tfile) _xxxN_t.eps                 #
# tfile contains a scaled letter in (in)visible grid #
# letter can be aligned using grid                   #
######################################################

tfile=_${fname}_t
echo "-> processing tile file: $tfile.tex"

cat >${tfile}.tex <<EOF
\documentclass[12pt]{article}
\usepackage{pstricks,pst-eps,graphicx}
\pagestyle{empty}
\begin{document}
\begin{TeXtoEPS}
\psset{gridlabels=0pt,gridwidth=0.1pt,subgridwidth=0.05pt}
\psset{xunit=75px,yunit=75px}
\begin{pspicture}(0,0)(1,1)
EOF
if [ $isGridOn -eq 1 ]
	then
		echo "-> using grid"
		cat >>${tfile}.tex <<EOF
\psgrid[gridcolor=gray,subgridcolor=gray,subgriddiv=6]
\psline[linecolor=gray,linewidth=0.1pt](0,0.438)(1,0.438)
EOF
fi
cat >>${tfile}.tex <<EOF
\rput(0.5,${yalign}){\includegraphics{${sfile}.eps}}
\end{pspicture}
\end{TeXtoEPS}
\end{document}
EOF

latex $tfile >/dev/null
dvips $tfile -E -o ${tfile}.eps >/dev/null 2>/dev/null
epstool --copy --bbox ${tfile}.eps temp.eps >/dev/null
mv temp.eps ${tfile}.eps
for i in aux log dvi tex
	do rm ${tfile}.${i}
done

#rm ${sfile}.eps

##################################################
# trim tfile if tile type ($pos) is 1, 2, 3 or 4 #
##################################################

# BoundingBox 72 645 147 720
#    is worked out from a typical letter (not a ki--yi) on a grid.
#    Value given by epstool is 71 644 148 721 but
#    to get 75x75 pix resolution, it is corrected.
#    This value also rounds the HiResBoundingBox value.

if [ $pos -gt 0 ] ; then

	# trim tile
	
	# first, make sure between llx and urx are the correct width
	#
	#     |<--- width --->|
	#   llx               urx
	#
	# if llx=m.5... then round it up (llx=llx+1) and then do urx=urx+1
	echo "-> trimming tile to fit letter"

	lx=`printf "%0.f\n" $hllx`
	echo "-> rounding $hllx to $lx \c"
	if [ $lx -gt $llx ]; then
		let ux=urx+1
		echo "and incr $urx to $ux"
	else
		let ux=urx
		echo "and $urx is not changed"
	fi
	
	# replace BB and HRBB with correct values
	cat >temp.sed <<EOF
1,/%%Bounding/s/%%BoundingBox:.*/%%BoundingBox: ${lx} 645 ${ux} 720/
1,/%%HiResBounding/s/%%HiResBoundingBox:.*/%%HiResBoundingBox: ${hllx} 644.935 ${hurx} 720.077/
EOF
	sed -f temp.sed ${tfile}.eps >temp.eps

	mv temp.eps ${tfile}.eps

else

	echo "-> tile corrected so it is 75x75 px"

sed '/%%BoundingBox/ c\
%%BoundingBox: 72 645 147 720\
' ${tfile}.eps >temp.eps

sed '/%%HiResBoundingBox/ c\
%%HiResBoundingBox: 71.936 644.935 147.077 720.077\
' temp.eps >${tfile}.eps

	rm temp.eps
fi


exit

#echo $pos
#if [ $pos -eq 3 ]
#	then
#		let x=llx+10
		# sed script to modify BoundingBox parameters only on the first occurrence
#		cat >temp.sed <<EOF
##--start of script--
##1{x;s/^/first/;x;}
##,/foo/{x;/first/s///;x;/%%BoundingBox/ c\ 
##%BoundingBox $x 645 147 720 
##}
##---end of script---
#/%%BoundingBox/s/.*/%%BoundingBox: ${x} ${lly} ${urx} ${ury}/
#EOF
#
#		echo did this
#		sed -f temp.sed $sfile.eps >test.eps
#fi


# write file info
# this contains the y-axis alignment of the letter
cat >>${1}${pos}.inf <<EOF
yalign: $yalign
EOF


convert ${tfile}.eps ${1}${pos}.png

