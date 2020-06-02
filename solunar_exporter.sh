#!/bin/bash
# solunar_exporter ver 0.1 - 02 June 2020 pvn <pvn@novarese.net>
#
# Copyright (C) 2020 Paul Novarese pvn@novarese.net
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
#
######
# Changelog:
#  New in v0.1 (02 June 2020):
#    initial release
#
# Requires solunar https://github.com/kevinboone/solunar_cmdline



# where to output .prom files (eg where your prom instance is looking for textfiles to consume)
PROMDIR=/home/pvn/prom

# requires solunar https://github.com/kevinboone/solunar_cmdline
SOLUNAR_EXE=/usr/local/bin/solunar

# I don't think this is necessary, not sure why I put this in
export TERM="vt100"
export TERMCAP="vt100"

# Initialize a few things
COORDINATES="+3505-08947" # Germantown, TN
                          #(for solunar sunrise/sunset time calcs)
MOONQUARTER=-1
SOLUNAR_MOONQUARTER=-1
SOLUNAR_SUNRISE=-1
SOLUNAR_SUNSET=-1
SOLUNAR_MOONRISE=-1
SOLUNAR_MOONSET=-1
SOLUNAR_MOONPHASE=-1
SOLUNAR_QUARTERSTRING=-1
SOLUNAR_MOONAGE=-1
SOLUNAR_MOONDISTANCE=-1


# solunar things

# I originally read all of this stuff in one go but solunar does something
# weird and has null output when (e.g.) there's not a moonset on a particular
# day, which complicates parsing of the output

# I could probably consolidate sunrise/sunset with the moon
# phase/quarter/age/distance at some point, but the overhead is pretty small

read -r SOLUNAR_SUNRISE SOLUNAR_SUNSET <<<$(${SOLUNAR_EXE} -l ${COORDINATES} -f |
               grep 'Sunrise\|Sunset' |
               sed s'/^.*: //' |
               sed s'/://' |
               tr '\n' ' ')
               # grep pulls out just sunrise/sunset
               # 1st sed to cut out beginning of line with the explanation of
               #     each output up to and including the colon
               # 2nd sed to remove colon in sun/moon rise/set times
               # tr to put all the output on one line

read -r SOLUNAR_MOONPHASE SOLUNAR_QUARTERSTRING SOLUNAR_MOONAGE SOLUNAR_MOONDISTANCE <<<$(${SOLUNAR_EXE} -l ${COORDINATES} -f |
               grep 'Moon ' |
               sed s'/^.*: //' |
               sed s'/.days\|.km//' |
               sed s'/ing /ing/' |
               sed s'/ quarter/quarter/' |
               tr '\n' ' ')
               # grep pulls out just Moon phase/quarter/age/distance
               # 1st sed to cut out beginning of line with the explanation of
               #     each output up to and including the colon
               # 2nd sed to remove unneeded days/kms units
               # 3rd sed to remove spaces b/t waxing/waning and gibbous/crescent
               # 4th sed to remove space between 1st/3rd and quarter
               # tr to put all the output on one line
read -r SOLUNAR_MOONRISE <<<$(${SOLUNAR_EXE} -l ${COORDINATES} -f |
               grep 'Moonrise' |
               sed s'/^.*: //' |
               sed s'/://' |
               tr '\n' ' ')
               # grep pulls out just moonrise/moonset
               # 1st sed to cut out beginning of line with the explanation of
               #     each output up to and including the colon
               # 2nd sed to remove colon in sun/moon rise/set times
               # tr to put all the output on one line

read -r SOLUNAR_MOONSET <<<$(${SOLUNAR_EXE} -l ${COORDINATES} -f |
               grep 'Moonset' |
               sed s'/^.*: //' |
               sed s'/://' |
               tr '\n' ' ')
               # grep pulls out just moonrise/moonset
               # 1st sed to cut out beginning of line with the explanation of
               #     each output up to and including the colon
               # 2nd sed to remove colon in sun/moon rise/set times
               # tr to put all the output on one line


# Moonrise/set check (sometimes there's not a moonrise or set on a given day)
if [ -z "$SOLUNAR_MOONSET" ]
then
    SOLUNAR_MOONSET=-1
fi

# Moonrise check
if [ -z "$SOLUNAR_MOONRISE" ]
then
    SOLUNAR_MOONRISE=-1
fi
# (convert the string of the moon's quarter into an integer for prom to consume)
case "${SOLUNAR_QUARTERSTRING}" in
 "new")
       SOLUNAR_MOONQUARTER=0 ;;
 "waxingcrescent")
       SOLUNAR_MOONQUARTER=1 ;;
 "1stquarter")
       SOLUNAR_MOONQUARTER=2 ;;
 "waxinggibbous")
       SOLUNAR_MOONQUARTER=3 ;;
 "full")
       SOLUNAR_MOONQUARTER=4 ;;
 "waninggibbous")
       SOLUNAR_MOONQUARTER=5 ;;
 "3rdquarter")
       SOLUNAR_MOONQUARTER=6 ;;
 "waningcrescent")
       SOLUNAR_MOONQUARTER=7 ;;
 esac


# spew into textfiles.  I used to shoot all of this into one big file
# but prometheus will ignore an entire textfile if any one metric is
# malformed.  So if one metric is null because of an unanticipated
# wrinkle or because (e.g.) there isn't a moonrise on a particular day,
# all data is lost, so I now put each metric into its own file

echo '# HELP sunrise time of sunrise' > ${PROMDIR}/solunar_sunrise.prom.$$
echo '# TYPE sunrise gauge' >> ${PROMDIR}/solunar_sunrise.prom.$$
echo 'sunrise ' ${SOLUNAR_SUNRISE} >> ${PROMDIR}/solunar_sunrise.prom.$$

mv ${PROMDIR}/solunar_sunrise.prom.$$ ${PROMDIR}/solunar_sunrise.prom

echo '# HELP sunset time of sunset' > ${PROMDIR}/solunar_sunset.prom.$$
echo '# TYPE sunset gauge' >> ${PROMDIR}/solunar_sunset.prom.$$
echo 'sunset ' ${SOLUNAR_SUNSET} >> ${PROMDIR}/solunar_sunset.prom.$$

mv ${PROMDIR}/solunar_sunset.prom.$$ ${PROMDIR}/solunar_sunset.prom

echo '# HELP moonrise time of moonrise' > ${PROMDIR}/solunar_moonrise.prom.$$
echo '# TYPE moonrise gauge' >> ${PROMDIR}/solunar_moonrise.prom.$$
echo 'moonrise ' ${SOLUNAR_MOONRISE} >> ${PROMDIR}/solunar_moonrise.prom.$$

mv ${PROMDIR}/solunar_moonrise.prom.$$ ${PROMDIR}/solunar_moonrise.prom

echo '# HELP moonset time of moonset' > ${PROMDIR}/solunar_moonset.prom.$$
echo '# TYPE moonset gauge' >> ${PROMDIR}/solunar_moonset.prom.$$
echo 'moonset ' ${SOLUNAR_MOONSET} >> ${PROMDIR}/solunar_moonset.prom.$$

mv ${PROMDIR}/solunar_moonset.prom.$$ ${PROMDIR}/solunar_moonset.prom

echo '# HELP solunarmoonphase Progression of Moon from New to New (0 to 1)' > ${PROMDIR}//solunar_phase.prom.$$
echo '# TYPE solunarmoonphase gauge' >> ${PROMDIR}//solunar_phase.prom.$$
echo 'solunarmoonphase ' ${SOLUNAR_MOONPHASE} >> ${PROMDIR}//solunar_phase.prom.$$

mv ${PROMDIR}/solunar_phase.prom.$$ ${PROMDIR}/solunar_phase.prom

echo '# HELP solunarmoonquarter Quarter of Moon (calculated by solunar)' > ${PROMDIR}/solunar_quarter.prom.$$
echo '# TYPE solunarmoonquarter gauge' >> ${PROMDIR}/solunar_quarter.prom.$$
echo 'solunarmoonquarter ' ${SOLUNAR_MOONQUARTER} >> ${PROMDIR}/solunar_quarter.prom.$$

mv ${PROMDIR}/solunar_quarter.prom.$$ ${PROMDIR}/solunar_quarter.prom

echo '# HELP solunarmoonage Age of Moon (in days)' > ${PROMDIR}/solunar_age.prom.$$
echo '# TYPE solunarmoonqge gauge' >> ${PROMDIR}/solunar_age.prom.$$
echo 'solunarmoonage ' ${SOLUNAR_MOONAGE} >> ${PROMDIR}/solunar_age.prom.$$

mv ${PROMDIR}/solunar_age.prom.$$ ${PROMDIR}/solunar_age.prom

echo '# HELP solunarmoondistance Distance of Moon (in km)' > ${PROMDIR}/solunar_distance.prom.$$
echo '# TYPE solunarmoondistance gauge' >> ${PROMDIR}/solunar_distance.prom.$$
echo 'solunarmoondistance ' ${SOLUNAR_MOONDISTANCE} >> ${PROMDIR}/solunar_distance.prom.$$

mv ${PROMDIR}/solunar_distance.prom.$$ ${PROMDIR}/solunar_distance.prom

exit 0
