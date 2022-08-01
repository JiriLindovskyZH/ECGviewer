ECGviewer

Use ECGviewer_1.631_installer.exe to install the app or open ECGviewer_1631.m in Matlab if you own the Matlab license.


This Matlab app opens and visualizes ECG data recorded by LabChart (ADInstruments) and exported as .mat file. ECG should be in channel 1, breath signal in channel 3, leave channel 2 selected and empty on export from LabChart. Simple analysis can be done as well, first of all R peak detection, manual R detection correction and averaging of ECG events aligned at R peaks. App allows to save various images created during analysis, it can save csv file with R-peak times and some more.

Use Example_ECG_data_short.mat (349 heart beats) or Example_ECG_data_long.mat (7619 heart beats) for testing of the app. After opening data ('Ctrl + o') press button 'Find R-peaks' or use keyboard shortcut 'r'.

The top plot can show either the original raw data, or data selected and edited by the user, or averaged PQRST events. Select between them by the buttons on the right side. Middle plot shows the breath signal. After R detection, bottom plot will show heart rate calculated for each two successive R peaks.

Selecting parts of the signal: use left and right mouse buttons inside the plot area to set limits of the selection. Selected area (highlighted by green color) can be modified using the buttons on the left prior the R-peak detection: a) 'Delete' it if signal contains noises in that portion, b) 'Select' it if all other portions of the signal are noisy except for the highlighted, 'Zoom In' the selection, 'Recover' it if you deleted it by mistake.

If you check the '3D plot' option in Analysis button group and detect R peaks again a color-coded composite plot will be calculated with all beats aligned at the time of R. Note: for large signals this can take a long time, even minutes. Within this color-coded plot you can use standard Matlab image tools to zoom in/out and even rotate the plot in 3D space. To adapt axes of the two complementary plots of the composite image to the current zoom press 'Adapt axes to 3D plot'.

See example images and csv files for comparison. Send comments/questions to: jiri.lindovsky@img.cas.cz


Keyboard shortcuts:
Ctrl + o, open data
r, detect R-peaks
z, zoom in or out to see complete highlighted area
a, zoom out to see all signal
d, delete highlighted area
+, zoom in (time axis)
-, zoom out (time axis)
arrows lef and right, small step on time axis
Ctrl + arrows, big step on time axis