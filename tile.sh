#!/bin/sh

# iPhone 4: screen res: 960x640 pix, pix density: 326 ppi
# iPhone 3: screen res: 480x320 pix, pix density: 136 ppi
# iPad 1,2: screen res: 1024×768 pix, pix density: 132 ppi
# new iPad: screen res: 2048x1536 pix, pix density: 264 ppi

# manual
# ./tile.sh -0 -t jim ja 
# single-standing jim spelled "ja" with default y-axis alignment and tiled
# ./tile.sh -2 -g -y 0.6 -d 72 jim --ja--
# middle jim with grid spelled "ja" with yalign=0.6, density=72


# DEFAULTS
# position of letter single, front, middle, end
pos=0
# y-axis alignment
yalign=0.5
# do not draw grid
isGridOn=0
# convert single letter (instead of tiled)
tile=0
# density value for ImageMagick 'convert'
dens=72


while getopts ":0123y:gtd:" opt; do
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
		y)
#			echo "setting y-coordinate alignment to $OPTARG"
			yalign=$OPTARG
			;;
		d)
#			echo "setting y-coordinate alignment to $OPTARG"
			dens=$OPTARG
			;;
		t)
			echo "converting tile to png"
			tile=1
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
		echo "-> single letter"
		;;
	1)
		echo "-> front letter"
		;;
	2)
		echo "-> middle letter"
		;;
	3)
		echo "-> rear letter"
		;;
esac

# y-coord alignment
echo "-> y-coordinate alignment is $yalign"

echo "-> making \"$str\" in file ${fname}.eps"

# letter file
lfile=_$fname
echo "-> making letter file: $lfile.tex"


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

# scale file
sfile=_${fname}_s
echo "-> making scaled file: ${sfile}.tex"

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

echo "-> finding boundingbox of $sfile.eps"
bbparam=`sed -n '/%%BoundingBox/{p;q;}' $sfile.eps`

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

echo "-> BoundingBox parameters for $sfile.eps are $llx $lly $urx $ury"

# tile file
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
\psgrid[gridcolor=darkgray,subgridcolor=gray,subgriddiv=6]
\psline[linecolor=darkgray,linewidth=0.1pt](0,0.438)(1,0.438)
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


sed '/%%BoundingBox/ c\
%%BoundingBox: 72 645 147 720\
' ${tfile}.eps >temp.eps

sed '/%%HiResBoundingBox/ c\
%%HiResBoundingBox: 71.936 644.935 147.077 720.077\
' temp.eps >${tfile}.eps

echo Position of letter $pos
echo trimming white space
if [ $pos -eq 3 ]
	then
		let x=llx+20
		# sed script to modify BoundingBox parameters only on the first occurrence
		cat >temp.sed <<EOF
#--start of script--
1{x;s/^/first/;x;}
1,/foo/{x;/first/s///;x;/%%BoundingBox/ c\ 
%%BoundingBox $x 645 147 720 
;}
#---end of script---
EOF

		echo did this with llx $x
		sed -f temp.sed $sfile.eps >test.eps
fi

rm temp.eps

# write file info
cat >>${1}${pos}.inf <<EOF
yalign: $yalign
EOF


#dens=80

if [ $tile -eq 0 ]
	then
		echo converting to single letter at density $dens
		convert -density $dens ${sfile}.eps ${1}${pos}.png
	else
		echo converting to tile
		convert ${tfile}.eps ${1}${pos}.png
fi

