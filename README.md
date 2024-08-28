# applyMRIMasks
 version 1.1
 21 Aug 2024
 Daniel Mendelson, working at Dr. Pedro Rosa-Neto's laboratory, McGill University, Montreal, Canada
 Prepared on computer running Ubuntu 20.04.6 LTS
 This software is shared according to the GNU General Public License v3.0
 This program is under no warranty.

~~ Overview ~~
* This software aims to apply MRI-based masks to PET images to extract SUV data and save results into a csv file.
* The default results uses outputs from the 'mincstats' software.
* In addition to a csv file containing results, this software also creates a log file to document the values of user-defined variables, the specific cases that are excluded from the output file (including the reasons why). 


~~ Contents of software ~~
* README.ME	- this text file
* config.cfg	- text file for user to define all necessary variable to run software
* config.shlib	- shell library containing functions used in the main shell script
* script.sh	- shell script to produce the results and log file   

~~ How to use ~~
0. Copy the program folder to a directory of choice (e.g., user-specific utilities directory)
1. Define variables in 'config.cfg' file.
2. Save 'config.cfg' file.
3. Open terminal in this program folder.
4. Call './script.sh' to run the script.
5. Consult output file whose path and name the user specifies, along with associated log file for details on what occured.

Error and warning messages should print to terminal when the script encounters unexpected values. Consult outputs to diagnose and resolve the issues, then attempt the script again. 
Depending on where in the script the error occured, log or results files may have been created.
 
Note:
	- Depending on the number of images and the resources available on to the user, this script may take 10 to 30 minutes to run. 
	- Tip: run this script using 'screen' or 'nohup' softwares; this allows you to close the terminal session without interrupt the script's functions. See https://en.wikipedia.org/wiki/Nohup
	
	
~~ Changing Actions of the Script ~~
By default, the script calls 'mincstats' with certain options and uses these outputs as contents of the main output file.
Depending on your specific needs, you may want to consider changing code beginning at lines 142 and especially lines 239 and 245 in the script.sh file.
Subsequent versions of this program may make the specific outputs created editable directly in the config.cfg file.


I encourage you to play around with these outputs to get what you need and to allow for easy reproduction of these exact results by yourself and others.
Wishing you as much patience and calm as you debug.	
Tip: Create a test input csv file with a couple rows copied directly from the source csv file; use this test csv file to test changes made to the script.
