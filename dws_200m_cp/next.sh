#!/bin/sh

out_dir=/fhgfs/client/kschulz/DWS200out/dws_200m_2/2009/11
hot_dir=/fhgfs/client/kschulz/DWS200out/dws_200m_2/2009/12

echo Output directory $out_dir
echo Hotfile directory $hot_dir

mv getm.inp $out_dir

echo moving hotfiles

mkdir -p $hot_dir
cp -f $out_dir/restart.*.out $hot_dir/

cd $hot_dir
rename .out .in *.out

echo finished...
