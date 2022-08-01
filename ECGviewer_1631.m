    % Reads MAT data exported from ECG module of LabChart. Should be able to
% view ECG and/or breath signal, automatically detect QRS complex and allow
% for manual editing (deleting, adding) events. Calculate heart rate, allow
% averaging of PQRST. Possibly also measure PQRST features.



clc;
clear all;
close all;

version = '2022-08-01';
%%
%============================ OPTIONS ===============================
% % Downsampling factor (must be integer, 1 = no downsample)
% % Is applied prior to any calculations - may affect correct detection of QRS
% % For 2 kHz sampling downQECG = 2 should be harmless
% downQECG = 2; %downsampling ECG signal
% downQBR = 80; %downsampling breath signal

global ECGch BRch showQRSdetection inputNumOfAverDef f4 viewedQRS3D

% Which channel is the ECG signal, which is breath?
ECGch = 1;
BRch = 3;


% Default x-axis range to plot on start of the program (ms)
% defaultXrange = [0,60000];

% Show the plot with QRS detection method?
showQRSdetection = 0;

% Default number of averaging PQRST neighbouring complexes
inputNumOfAverDef = 1; % 1 means no averaging

% Default filtering options
defFiltOpt = [1,3,300]; % [whether to filter on load, low limit (Hz), high limit (Hz)]

%========================= END OF OPTIONS ============================== 
%%
disp('ECG + breath signal viewing and heart rate measurement.');

global header
global DATA f1 dat xRange yRange
global current %currently selected/viewed signal (handle to figure and data)
%temporary variables, global only for coding purpose, delete from global in
%working version
global message mycolormap

% Initiate global variables
resetGlobals();

% Show gui ================================================================
% Figure, information about version, header, messages
f1 = figure;
set(f1, 'units', 'normalized', 'position',[0,0.03,1,0.92], 'menubar','none',...
    'toolbar','none','name',['ECG viewer, version ',version],'NumberTitle','off',...
    'windowstyle', 'normal');
set(f1,'WindowKeyPressFcn',@keyPress);
header = uicontrol('style','text','string','Mouse ECG signal viewer and analyser', 'units','normalized',...
    'position',[0,0.95,1,0.05], 'fontsize',16);
message = uicontrol('style','text','string','','units','normalized',...
    'position',[0,0.93,1,0.03], 'fontsize',13);

% Subplots================================================================
% Subplot for ECG signal
global sp1 sp2 sp3 plotECGsig
sp1 = subplot('Position', [0.15,0.55,0.75,0.35]);
% Plot currently selected interval
plotSelection = plot(sp1,current.selection,[0,0],'linewidth', 200, 'color',[0.60,0.70,0.40]);
hold on;
% Plot detected QRS
plotQRSs = scatter(sp1,DATA.QRS.time,DATA.QRS.amplitude);
% Plot signal
plotECGsig = plot(sp1,DATA.ECG.orig.time,DATA.ECG.orig.signal, 'color', [0,0,0]);
set(sp1,'XAxisLocation','top','box','on');
hold off

% Subplot for breath signal
sp2 = subplot('Position', [0.15,0.4,0.75,0.15]);
plotBreathSig = plot(sp2,DATA.breath.orig.time,DATA.breath.orig.signal, 'color', [0,0,0]);
set(sp2,'xticklabels',[],'box','on');

% Subplot for heart rate
sp3 = subplot('Position', [0.15,0.20,0.75,0.2],'box','on');
plotHR = plot(sp3,DATA.HR.time,DATA.HR.signal, 'color', [0.2,0,0]);


%% Buttons==================================================================
global butSelectFile navButGroup selectionToolGroup editingToolGroup analysisToolGroup 
global subplotSelectionGroup but_editQRSenable but_editQRSdisable but_recalculateHR
global exportCSVgroup but_ExportSelEditECGcsv but_ExportQRStimeCsv but_PQRSTaverager inputNumOfAver but_cancel
global but_ExportAverQRScsv chck3Dplot filterOnLoad filtersGroup BPlow BPhigh but_unfilter

butSelectFile = uicontrol('style','pushbutton','string','Open data file', 'units','normalized',...
    'position',[0.02,0.88,0.1,0.1],'fontsize',13,'FontWeight','bold','callback',@selectFile);

% buttons to control zooming and moving through the signal
navButGroup = uibuttongroup('units','normalized','position',[0.4,0.015,0.2,0.18],'Title','Navigation',...
    'visible','on');
    but_moveLbig = uicontrol(navButGroup,'style','pushbutton','string','<<', 'units','normalized',...
        'position',[0.2,0.4,0.1,0.4],'fontsize',20,'callback',{@moveThroughSignal,'<<'});
    but_moveLsmall = uicontrol(navButGroup,'style','pushbutton','string','<-', 'units','normalized',...
        'position',[0.3,0.4,0.1,0.4],'fontsize',20,'callback',{@moveThroughSignal,'<'});
    but_moveRsmall = uicontrol(navButGroup,'style','pushbutton','string','->', 'units','normalized',...
        'position',[0.6,0.4,0.1,0.4],'fontsize',20,'callback',{@moveThroughSignal,'>'});
    but_moveRBig = uicontrol(navButGroup,'style','pushbutton','string','>>', 'units','normalized',...
        'position',[0.7,0.4,0.1,0.4],'fontsize',20,'callback',{@moveThroughSignal,'>>'});
    but_zoomInX = uicontrol(navButGroup,'style','pushbutton','string','<+>', 'units','normalized',...
        'position',[0.8,0.4,0.2,0.4],'fontsize',20,'callback',{@moveThroughSignal,'x+'});
    but_zoomOutX = uicontrol(navButGroup,'style','pushbutton','string','>-<', 'units','normalized',...
        'position',[0,0.4,0.2,0.4],'fontsize',20,'callback',{@moveThroughSignal,'x-'});
    but_zoomInY = uicontrol(navButGroup,'style','pushbutton','string','+', 'units','normalized',...
        'position',[0.4,0.8,0.2,0.2],'fontsize',20,'callback',{@moveThroughSignal,'y+'});
    but_zoomOutY = uicontrol(navButGroup,'style','pushbutton','string','-', 'units','normalized',...
        'position',[0.4,0.2,0.2,0.2],'fontsize',20,'callback',{@moveThroughSignal,'y-'});
    but_shiftYup = uicontrol(navButGroup,'style','pushbutton','string','^', 'units','normalized',...
        'position',[0.2,0.8,0.2,0.2],'fontsize',20,'callback',{@moveThroughSignal,'^'});
    but_shiftYdown = uicontrol(navButGroup,'style','pushbutton','string','v', 'units','normalized',...
        'position',[0.6,0.8,0.2,0.2],'fontsize',14,'callback',{@moveThroughSignal,'v'});
    but_xStart = uicontrol(navButGroup,'style','pushbutton','string','Start', 'units','normalized',...
        'position',[0.1,0,0.2,0.2],'fontsize',12,'callback',{@moveThroughSignal,'xStart'});
    but_xAll = uicontrol(navButGroup,'style','pushbutton','string','All', 'units','normalized',...
        'position',[0.4,0,0.2,0.2],'fontsize',12,'callback',{@moveThroughSignal,'xAll'});
    but_xEnd = uicontrol(navButGroup,'style','pushbutton','string','End', 'units','normalized',...
        'position',[0.7,0,0.2,0.2],'fontsize',12,'callback',{@moveThroughSignal,'xEnd'});
    but_autoY = uicontrol(navButGroup,'style','pushbutton','string','Auto Y', 'units','normalized',...
        'position',[0.42,0.44,0.16,0.32],'fontsize',11,'callback',{@moveThroughSignal,'autoY'});
    but_zoomInSelection = uicontrol(navButGroup,'style','pushbutton','string','Zoom Selected','units','normalized',...
        'position',[0.8,0.8,0.2,0.2],'callback',{@applyToSelection,'zoomIn'});

% Buttons for applying functions and analysis to selected region of signal
selectionToolGroup = uibuttongroup('units','normalized','position',[0.02,0.65,0.1,0.2],'Title','Highlighted region');
    but_zoomIn = uicontrol(selectionToolGroup,'style','pushbutton','string','Zoom In (z)','units','normalized',...
        'position',[0,0.7,1,0.3],'callback',{@applyToSelection,'zoomIn'});
    but_zeroSignal = uicontrol(selectionToolGroup,'style','pushbutton','string','Delete (d)','units','normalized',...
        'position',[0,0.4,1,0.2],'callback',{@applyToSelection,'zero'});
    but_restoreSignal = uicontrol(selectionToolGroup,'style','pushbutton','string','Recover','units','normalized',...
        'position',[0,0.2,1,0.2],'callback',{@applyToSelection,'restore'});
    but_selectForAnalysis = uicontrol(selectionToolGroup,'style','pushbutton','string','Select','units','normalized',...
        'position',[0,0,1,0.2],'callback',{@applyToSelection,'select'});
set(selectionToolGroup.Children,'FontSize',11);

% Buttons for signal editing
editingToolGroup = uibuttongroup('units','normalized','position',[0.02,0.42,0.1,0.2],'Title','Signal manipulation');
    but_invert = uicontrol(editingToolGroup,'style','pushbutton','string','Invert','units','normalized',...
        'position',[0,0.8,1,0.2],'callback',{@invert});
    % Buttons for 50Hz hum removal
    filtersGroup = uibuttongroup(editingToolGroup,'units','normalized','position',[0,0.2,1,0.6],...
        'Title','Filters');
        filterOnLoad = uicontrol(filtersGroup,'style','checkbox','units','normalized','position',[0.1,0.8,0.9,0.2],'string',...
            'Filter on Load','Value',defFiltOpt(1));
        BPlow = uicontrol(filtersGroup,'style','edit','units','normalized','position',[0.44,0.4,0.3,0.3],...
            'string',defFiltOpt(2),'FontSize',11);
        BPlowText = uicontrol(filtersGroup,'style','text','units','normalized','position',[0.03,0.36,0.4,0.3],...
            'string','Low (Hz)','FontSize',11);
        BPhigh = uicontrol(filtersGroup,'style','edit','units','normalized','position',[0.44,0.05,0.3,0.3],...
            'string',defFiltOpt(3),'FontSize',11);
        BPhighText = uicontrol(filtersGroup,'style','text','units','normalized','position',[0.03,0,0.4,0.3],...
            'string','High (Hz)','FontSize',11);
        but_filter = uicontrol(filtersGroup,'style','pushbutton','string','Filter','units','normalized',...
            'position',[0.74,0.03,0.24,0.68],'callback',{@filterBP,'BPfilter'});
    but_unfilter = uicontrol(editingToolGroup,'style','pushbutton','string','Restore','units','normalized',...
            'position',[0,0,1,0.2],'callback',{@filterBP,'unfilter'});

set(but_invert,'FontSize',11);

% Buttons for analysis    
analysisToolGroup = uibuttongroup('units','normalized','position',[0.02,0.19,0.1,0.2],'Title','Analysis');
    but_findQRS = uicontrol(analysisToolGroup,'style','pushbutton','string','Find R-peaks','units','normalized',...
        'position',[0,0.8,0.5,0.2],'callback',{@findQRS});
%     but_loadRS = uicontrol(analysisToolGroup,'style','pushbutton','string','Load R-peaks','units','normalized',...
%         'position',[0.5,0.8,0.5,0.2],'callback',{@loadQRS});

% checkbox enabling 3D plot of PQRST
    chck3Dplot = uicontrol(analysisToolGroup,'style','checkbox','units','normalized','position',[0.6,0.85,0.8,0.15],'string',...
        '3D plot','Value',0);
    manualQRStoolGroup = uibuttongroup(analysisToolGroup,'units','normalized','position',[0,0.5,1,0.3],'Title','Manual QRS editing');
        but_editQRSenable = uicontrol(manualQRStoolGroup,'style','pushbutton','string','Enable','units','normalized',...
            'position',[0,0,0.5,1],'callback',{@editQRSenable,'on'});
        but_editQRSdisable = uicontrol(manualQRStoolGroup,'style','pushbutton','string','Disable','units','normalized',...
            'position',[0.5,0,0.5,1],'callback',{@editQRSenable,'off'});
    but_recalculateHR = uicontrol(analysisToolGroup,'style','pushbutton','string','Recalculate Heart Rate','units','normalized',...
        'position',[0,0.3,1,0.2],'callback',{@calculateHR});
    but_PQRSTaverager = uicontrol(analysisToolGroup,'style','pushbutton','string','Average QRS:','units','normalized',...
        'position',[0,0,0.5,0.2],'callback',{@PQRSTaverager});
    inputNumOfAver = uicontrol(analysisToolGroup,'style','edit','string',inputNumOfAverDef,'units','normalized',...
        'position',[0.5,0,0.3,0.2],'FontSize',11);
    but_cancel = uicontrol(analysisToolGroup,'style','pushbutton','string','X','units','normalized',...
        'position',[0.8,0,0.2,0.2],'FontSize',18,'callback',{@cancelAverager});
    global cancelAveraging
    cancelAveraging = 0;

% Buttons related to export
exportCSVgroup = uibuttongroup('units','normalized','position',[0.78,0.02,0.1,0.15],'Title','Export .csv');
    but_ExportSelEditECGcsv = uicontrol(exportCSVgroup,'style','pushbutton','string','Selected edited ECG','units','normalized',...
        'position',[0.05,0.8,0.9,0.2],'callback',{@exportCSV,'selectedEditedECGcsv'});
    but_ExportQRStimeCsv = uicontrol(exportCSVgroup,'style','pushbutton','string','R-peak times + heart rate','units','normalized',...
        'TooltipString','Export times of R-peaks (ms) and heart rate (bpm)',...
        'position',[0.05,0.6,0.9,0.2],'callback',{@exportCSV,'QRStimes'});
    but_ExportAverQRScsv = uicontrol(exportCSVgroup,'style','pushbutton','string','Selected aver. QRS','units','normalized',...
        'TooltipString','Export times of R-peaks (ms) and heart rate (bpm)',...
        'position',[0.05,0.4,0.9,0.2],'callback',{@exportCSV,'averQRS'});

% Buttons for plot selection
subplotSelectionGroup = uibuttongroup('units','normalized','position',[0.9,0.198,0.07,0.71],'Title','View plot');
    but_selECGorig = uicontrol(subplotSelectionGroup,'style','pushbutton','string','Original ECG','units','normalized',...
        'position',[0,0.9,1,0.1],'FontSize',11,'callback',{@chooseSubplot,'sp1','ECGorig'});
    but_selECGedited = uicontrol(subplotSelectionGroup,'style','pushbutton','string','ECG edited for analysis','units','normalized',...
        'position',[0,0.8,1,0.1],'callback',{@chooseSubplot,'sp1','forAnalysis'});
    but_selPQRSaver = uicontrol(subplotSelectionGroup,'style','pushbutton','string','Averaged PQRST','units','normalized',...
        'position',[0,0.7,1,0.05],'callback',{@chooseSubplot,'sp1','PQRSaver'});
    but_selBreathorig = uicontrol(subplotSelectionGroup,'style','pushbutton','string','Original Breath','units','normalized',...
        'position',[0,0.408,1,0.1],'FontSize',11,'callback',{@chooseSubplot,'sp2','BreathOrig'});
    but_selHRorig = uicontrol(subplotSelectionGroup,'style','pushbutton','string','Heart rate','units','normalized',...
        'position',[0,0.189,1,0.1],'FontSize',11,'callback',{@chooseSubplot,'sp3','HR'});

% Styling of button groups
set([navButGroup,selectionToolGroup,editingToolGroup,analysisToolGroup,subplotSelectionGroup,exportCSVgroup],'FontSize',10);

% Disable all buttons apart from data opening
enableButtons('all','off');
enableButtons([butSelectFile,BPlow,BPhigh],'on');

%%

showMessage(['Program started at: ',datestr(datetime('now'))],'black');

%% Open example data automatically to speed up coding (remove in functional versions)
%         global fileIn pathF
%         fileIn = '\Example data.mat'; pathF = cd;
%         openFile(); %Don't forget to uncomment ui question about ECG and breath channels!
% 
%         findQRS();
%         editQRSenable('','','on');
%%=================================================================================
    

mycolormap = [0.00196078442968428 0.00196078442968428 0.00196078442968428;0.0590414181351662 0.0590414181351662 0.0590414181351662;0.116122052073479 0.116122052073479 0.116122052073479;0.173202678561211 0.173202678561211 0.173202678561211;0.230283319950104 0.230283319950104 0.230283319950104;0.287363946437836 0.287363946437836 0.287363946437836;0.344444572925568 0.344444572925568 0.344444572925568;0.401525229215622 0.401525229215622 0.401525229215622;0.458605855703354 0.458605855703354 0.458605855703354;0.515686511993408 0.515686511993408 0.515686511993408;0.539022386074066 0.513318181037903 0.515854775905609;0.562358260154724 0.508437812328339 0.51908004283905;0.585694193840027 0.501300573348999 0.526285529136658;0.60903012752533 0.491906404495239 0.538139462471008;0.632366061210632 0.480255305767059 0.555309951305389;0.65570193529129 0.466347277164459 0.578465163707733;0.679037868976593 0.450182318687439 0.608273327350616;0.702373802661896 0.431760430335999 0.645402550697327;0.725709736347198 0.411081612110138 0.690521001815796;0.749045670032501 0.388145864009857 0.744296908378601;0.737364709377289 0.362953186035156 0.772381544113159;0.710941255092621 0.335503578186035 0.795717477798462;0.673855900764465 0.305797070264816 0.819053411483765;0.625440418720245 0.273833602666855 0.842389345169067;0.565026700496674 0.239613220095634 0.865725219249725;0.491946518421173 0.203135892748833 0.889061152935028;0.405531734228134 0.164401650428772 0.912397086620331;0.305114179849625 0.123410478234291 0.935733020305634;0.19002565741539 0.08016237616539 0.959068953990936;0.109408468008041 0.0787218362092972 0.963358104228973;0.0772653222084045 0.126791164278984 0.967647314071655;0.0757928192615509 0.206571266055107 0.971936464309692;0.0743043422698975 0.287379860877991 0.976225674152374;0.0727998837828636 0.369221270084381 0.980514883995056;0.0712794438004494 0.452099829912186 0.984804034233093;0.0697430148720741 0.536019861698151 0.989093244075775;0.0681906193494797 0.620985686779022 0.993382394313812;0.0666222348809242 0.707001686096191 0.997671604156494;0.0650378689169884 0.794072151184082 1;0.0634279027581215 0.882684826850891 1;0.0618179328739643 0.97160279750824 1;0.061111256480217 0.98577094078064 1;0.0604045838117599 0.999960422515869 1;0.0596979074180126 1 0.989750385284424;0.0589912310242653 1 0.97551828622818;0.0582845583558083 1 0.961264848709106;0.0575778819620609 1 0.946990132331848;0.0865060985088348 1 0.892269730567932;0.115434311330318 1 0.841114163398743;0.172436326742172 1 0.750031352043152;0.228646114468575 0.994397878646851 0.673421859741211;0.284078866243362 0.987675249576569 0.611017823219299;0.338734537363052 0.980952560901642 0.562548339366913;0.392613142728806 0.97422993183136 0.527742624282837;0.445714712142944 0.967507243156433 0.506329834461212;0.498039215803146 0.960784614086151 0.498039215803146;0.504911243915558 0.966912031173706 0.451009541749954;0.522386729717255 0.973039448261261 0.403342306613922;0.550665497779846 0.979166865348816 0.355037540197372;0.58994734287262 0.985294282436371 0.306095242500305;0.640432119369507 0.991421699523926 0.25651541352272;0.70231968164444 0.997549116611481 0.206298038363457;0.775808751583099 1 0.155438989400864;0.86109858751297 1 0.103926993906498;0.888713002204895 1 0.0884772911667824;0.917343556880951 1 0.0730275884270668;0.946990132331848 1 0.0575778819620609;0.953632175922394 1 0.0530767254531384;0.960339784622192 1 0.0485755689442158;0.967112839221954 1 0.0440744124352932;0.973951458930969 1 0.0395732559263706;0.980855524539948 1 0.035072099417448;0.987825095653534 1 0.0305709410458803;0.994860172271729 1 0.0260697845369577;1 1 0.0215686280280352;1 0.944290637969971 0.0215686280280352;1 0.88662052154541 0.0215686280280352;1 0.82895040512085 0.0215686280280352;1 0.771280288696289 0.0215686280280352;1 0.713610172271729 0.0215686280280352;1 0.655939996242523 0.0215686280280352;1 0.598269879817963 0.0215686280280352;1 0.540599763393402 0.0215686280280352;1 0.482929646968842 0.0215686280280352;1 0.425259530544281 0.0215686280280352;1 0.367589384317398 0.0215686280280352;1 0.309919267892838 0.0215686280280352;1 0.252249121665955 0.0215686280280352;1 0.194579005241394 0.0215686280280352;1 0.136908888816833 0.0215686280280352;1 0.0792387574911118 0.0215686280280352;1 0.0215686280280352 0.0215686280280352;1 0.0216692499816418 0.0218242090195417;1 0.0219818502664566 0.0226157400757074;1 0.0222944505512714 0.0234069637954235;1 0.0226070508360863 0.0241978820413351;1 0.0229196511209011 0.0249884966760874;1 0.0232322514057159 0.02577880397439;1 0.0235448516905308 0.0265688057988882;1 0.0238574501127005 0.0273585021495819;1 0.0241700503975153 0.0281478930264711;1 0.0244826506823301 0.0289369784295559;1 0.024795250967145 0.0297257583588362;1 0.0251078512519598 0.030514232814312;1 0.0281987339258194 0.0335365794599056;1 0.0312895067036152 0.0365591458976269;1 0.034380167722702 0.0395819284021854;1 0.0374707169830799 0.0426049269735813;1 0.0405611544847488 0.0456281453371048;1 0.0436514839529991 0.0486515797674656;1 0.0467416979372501 0.0516752302646637;1 0.0498318038880825 0.0546991005539894;1 0.0529218018054962 0.0577231869101524;1 0.0560116842389107 0.0607474893331528;1 0.0591014586389065 0.0637720078229904;1 0.0621911212801933 0.066796749830246;1 0.0652806684374809 0.0698217079043388;1 0.0683701112866402 0.0728468745946884;1 0.0714594423770905 0.0758722648024559;1 0.0745486617088318 0.0788978710770607;1 0.0776377692818642 0.0819237008690834;1 0.0807267650961876 0.0849497392773628;1 0.0838156491518021 0.0879760012030602;1 0.0869044288992882 0.0910024717450142;1 0.0899930894374847 0.0940291658043861;1 0.0930816456675529 0.0970560759305954;1 0.0961700826883316 0.100083202123642;1 0.0992584154009819 0.103110544383526;1 0.102346636354923 0.106138110160828;1 0.105434745550156 0.109165884554386;1 0.108522742986679 0.112193882465363;1 0.111610628664494 0.115222088992596;1 0.11469841003418 0.118250519037247;1 0.117786072194576 0.121279165148735;1 0.120873630046844 0.124308027327061;1 0.123961068689823 0.127337113022804;1 0.127048403024673 0.130366399884224;1 0.130135625600815 0.133395925164223;1 0.133222743868828 0.136425644159317;1 0.136309742927551 0.13945560157299;1 0.139396622776985 0.142485752701759;1 0.142483398318291 0.145516142249107;1 0.145570069551468 0.148546740412712;1 0.148656621575356 0.151577547192574;1 0.151743069291115 0.154608577489853;1 0.154829412698746 0.15763983130455;1 0.157915636897087 0.160671293735504;1 0.161001741886139 0.163702979683876;1 0.164087742567062 0.166734874248505;1 0.167173638939857 0.169766992330551;1 0.170259416103363 0.172799319028854;1 0.17334508895874 0.175831869244576;1 0.176430642604828 0.178864628076553;1 0.179516091942787 0.181897610425949;1 0.182601422071457 0.184930801391602;1 0.185686647891998 0.187964215874672;1 0.188771769404411 0.19099785387516;1 0.191856771707535 0.194031700491905;1 0.194941654801369 0.197065770626068;1 0.198026448488235 0.200100049376488;1 0.201111108064651 0.203134536743164;1 0.2041956782341 0.206169247627258;1 0.20728012919426 0.20920418202877;1 0.210364460945129 0.212239325046539;1 0.213448688387871 0.215274691581726;1 0.216532796621323 0.21831026673317;1 0.219616815447807 0.221346065402031;1 0.222700700163841 0.224382072687149;1 0.225784480571747 0.227418303489685;1 0.228868156671524 0.230454742908478;1 0.231951713562012 0.233491405844688;1 0.235035166144371 0.236528277397156;1 0.238118514418602 0.239565372467041;1 0.241201743483543 0.242602676153183;1 0.244284853339195 0.245640203356743;1 0.247367858886719 0.248677954077721;1 0.250450760126114 0.251715898513794;1 0.253533542156219 0.254754066467285;1 0.256616204977036 0.257792472839355;1 0.259698778390884 0.260831087827682;1 0.262781232595444 0.263869911432266;1 0.265863567590714 0.266908943653107;1 0.268945813179016 0.269948184490204;1 0.272027909755707 0.27298766374588;1 0.27510991692543 0.276027351617813;1 0.278191834688187 0.279067248106003;1 0.281273603439331 0.282107353210449;1 0.284355282783508 0.285147696733475;1 0.287436842918396 0.288188248872757;1 0.290518313646317 0.291229009628296;1 0.293599635362625 0.294270008802414;1 0.296680867671967 0.297311186790466;1 0.299762010574341 0.300352603197098;1 0.302843004465103 0.303394228219986;1 0.305923908948898 0.306436091661453;1 0.309004694223404 0.309478163719177;1 0.312085390090942 0.312520414590836;1 0.315165936946869 0.315562933683395;1 0.318246394395828 0.31860563158989;1 0.321326732635498 0.321648567914963;1 0.324406981468201 0.32469168305397;1 0.327487111091614 0.327735036611557;1 0.330567121505737 0.330778628587723;1 0.333647012710571 0.333822399377823;1 0.336726814508438 0.336866408586502;1 0.339806467294693 0.339910626411438;1 0.342886060476303 0.342955052852631;1 0.345965504646301 0.345999717712402;1 0.34901961684227 0.34901961684227;1 0.362823724746704 0.362879782915115;1 0.377043724060059 0.377097368240356;1 0.391264915466309 0.391316175460815;1 0.405487298965454 0.405536234378815;1 0.419710844755173 0.419757544994354;1 0.433935582637787 0.433980047702789;1 0.448161512613297 0.448203831911087;1 0.462388604879379 0.46242880821228;1 0.476616889238358 0.476655036211014;1 0.490846365690231 0.490882515907288;1 0.505077004432678 0.505111217498779;1 0.519308805465698 0.519341170787811;1 0.533541858196259 0.533572316169739;1 0.54777604341507 0.547804713249207;1 0.562011420726776 0.562038362026215;1 0.576247930526733 0.576273262500763;1 0.590485692024231 0.590509414672852;1 0.604724645614624 0.604746758937836;1 0.618964731693268 0.61898535490036;1 0.633206009864807 0.63322514295578;1 0.647448480129242 0.64746618270874;1 0.661692142486572 0.661708474159241;1 0.675936937332153 0.675952017307281;1 0.690182983875275 0.690196812152863;1 0.704430162906647 0.704442799091339;1 0.718678534030914 0.718690037727356;1 0.732928097248077 0.732938528060913;1 0.747178852558136 0.747188210487366;1 0.761430740356445 0.761439144611359;1 0.775683879852295 0.775691330432892;1 0.789938151836395 0.789944767951965;1 0.804193615913391 0.804199397563934;1 0.818450272083282 0.818455278873444;1 0.832708120346069 0.832712411880493;1 0.846967101097107 0.846970796585083;1 0.861227333545685 0.861230373382568;1 0.875488698482513 0.875491201877594;1 0.889751255512238 0.88975328207016;1 0.904015004634857 0.904016554355621;1 0.918279886245728 0.918281078338623;1 0.932546019554138 0.932546854019165;1 0.9468132853508 0.946813881397247;1 0.961081802845001 0.961082100868225;1 0.975351452827454 0.975351631641388;1 0.989622294902802 0.989622354507446;1 1 1;1 1 1];
    
%% Functions

function editQRSenable(~,~,onoff)
    global but_editQRSenable but_editQRSdisable plotECGsig sp1
    if isequal(onoff,'on')
        % set callback to subplot1 to interact with array of QRS
        set(plotECGsig,'ButtonDownFcn',@editQRS);
        
        % Make the subplot current and styled as active
        chooseSubplot('','','sp1','forAnalysis');
        replot('active');
        
        %enable/disable buttons
        enableButtons(but_editQRSenable,'off');
        enableButtons(but_editQRSdisable,'on');
    else
        % set callback back to selection in axes
        set(plotECGsig,'ButtonDownFcn',{@selectInAxes,sp1});
        %enable/disable buttons
        enableButtons(but_editQRSenable,'on');
        enableButtons(but_editQRSdisable,'off');
    end
end

function chooseSubplot(~,~,which_subplot,whichSubplotLine)
    global DATA current sp1 sp2 sp3
    current.subplotLine = whichSubplotLine;
    switch which_subplot
        case 'sp1'
            current.subplot = sp1;
            switch whichSubplotLine
                case 'ECGorig'
                    current.signal = DATA.ECG.orig.signal;
                    current.time = DATA.ECG.orig.time;
                    current.samplF = DATA.ECG.orig.samplF;
                    messageText = 'Active plot: ECG original recording';
                    messageColor = 'black';
                case 'forAnalysis'
                    current.signal = DATA.ECG.forAnalysis.signal;
                    current.time = DATA.ECG.forAnalysis.time;
                    current.samplF = DATA.ECG.orig.samplF;
                    messageText = 'Active plot: Edited ECG signal (this will be used for QRS detection)';
                    messageColor = 'blue';
                case 'PQRSaver'
                    current.signal = DATA.ECG.averQRS.signal;
                    current.time = DATA.ECG.forAnalysis.time;
                    current.samplF = DATA.ECG.orig.samplF;
                    messageText = 'Active plot: Averaged P-QRS-T';
                    messageColor = [0.5 0.5 0];
            end
            
        case 'sp2'
            current.subplot = sp2;
            switch whichSubplotLine
                case 'BreathOrig'
                    current.signal = DATA.breath.orig.signal;
                    current.time = DATA.breath.orig.time;
                    current.samplF = DATA.breath.orig.samplF;
                    messageText = 'Active plot: original breath recording';
                    messageColor = 'black';
            end
            
        case 'sp3'
            current.subplot = sp3;
            switch whichSubplotLine
                case 'HR'
                    current.signal = DATA.HR.signal;
                    current.time = DATA.HR.time;
                    current.samplF = NaN;
                    messageText = 'Active plot: Heart rate';
                    messageColor = 'black';
            end
    end
    showMessage(messageText,messageColor);
    replot('active');
    replot('data');
end

function editQRS(~,e)
    global DATA but_recalculateHR
    signal = DATA.ECG.forAnalysis.signal;
    time = DATA.ECG.forAnalysis.time;
%     sF = DATA.ECG.forAnalysis.samplF;
    QRStime = DATA.QRS.time;
    QRSamplit = DATA.QRS.amplitude;
    % Neighbourhood of the QRS which will be considerd close for detection
    nbhd = 28;% in miliseconds
    % Allow looking for maxima?
        
    % Find nearest point on time axis of signal as well as nearest QRS
    % and decide if the click was in the neighbourhood of the QRS
    tidx = getTimeIdxs(time,e.IntersectionPoint(1));
    QRSidx = getTimeIdxs(QRStime,e.IntersectionPoint(1));
    QRSt = QRStime(QRSidx);
    isNbhd =  abs(e.IntersectionPoint(1) - QRSt) < nbhd;
%     showMessage(string(isNbhd),'red');
    
    switch e.Button
        case 1 %left click
            if isNbhd
                % if clicked in QRS neighbourhood, replace old QRS with new
                QRStime(QRSidx) = time(tidx);
                QRSamplit(QRSidx) = signal(tidx);
            else
                % otherwise add new QRS
                QRStime = [QRStime,time(tidx)];
                QRSamplit = [QRSamplit,signal(tidx)];
            end
        case 3 % right click, delete QRS if it is somewhere near
            if isNbhd
                % if clicked in QRS neighbourhood, remove
                QRStime(QRSidx) = [];
                QRSamplit(QRSidx) = [];
            end
    end
    
    % Checke for duplicates?
    % Sort
    [QRStime,sortIdx] = sort(QRStime);
    QRSamplit = QRSamplit(sortIdx);
    
    % Put edited QRS back to data
    DATA.QRS.time = QRStime;
    DATA.QRS.amplitude = QRSamplit;
    
    % Make the subplot current and styled as active
    chooseSubplot('','','sp1','forAnalysis');
    replot('data');
    replot('active');
    
    % Enable button for heart rate recalculation
    enableButtons(but_recalculateHR,'on');
    
end

function findQRS(~,~)
global DATA current showQRSdetection but_editQRSenable but_ExportQRStimeCsv
global but_PQRSTaverager inputNumOfAver fileIn chck3Dplot
% inspired by Pan-Tompkin algorithm, but simplified and adapted for mouse
% See also interesting documents on researchgate.
% https://www.researchgate.net/publication/313673153_Matlab_Implementation_of_Pan_Tompkins_ECG_QRS_detector

% Show waitbar
w = waitbar(0,'Searching for QRS');
% Band-pass filter (10 - 200)
fL = 10;                                          % cuttoff low frequency to get rid of baseline wander
 fH=200;                                          % cuttoff frequency to discard high frequency noise
 Wn=[fL fH]*2/DATA.ECG.orig.samplF;               % cutt off based on fs
 N = 3;                                           % order of 3 less processing
 [a,b] = butter(N,Wn);                            % bandpass filtering
 DATA.ECG.BPfiltered.signal = filtfilt(a,b,DATA.ECG.forAnalysis.signal);
 DATA.ECG.BPfiltered.signal = DATA.ECG.BPfiltered.signal/max( abs(DATA.ECG.BPfiltered.signal));
 
 % Squaring
 DATA.ECG.squared.signal = DATA.ECG.BPfiltered.signal .* DATA.ECG.BPfiltered.signal;
 waitbar(0.1);
 % Moving maximum (window length 15 ms?)
 window = round(15 / 1000 * DATA.ECG.orig.samplF);
 DATA.ECG.movMax.signal = movmax(DATA.ECG.squared.signal, window);
 DATA.ECG.movMax.signal = DATA.ECG.movMax.signal / max(abs(DATA.ECG.movMax.signal));
 
 % Finding some kind of envelope (window 500 ms?)
 window = round(500 / 1000 * DATA.ECG.orig.samplF);
 DATA.ECG.movAver.signal = 1.5 * movmean(DATA.ECG.movMax.signal,window);
 waitbar(0.2);
 % Prepare vector where 0 represents signal < threshold and 1 signal >
 % threshold
 aboveThr = zeros(size(DATA.ECG.forAnalysis.signal));
 aboveThr(find(DATA.ECG.movMax.signal>DATA.ECG.movAver.signal))=1;
 % Find all beginnings of ones in the vector
 % First define how long should be zeros (regions without QRS) and how long
 % the ones (regions with QRS)
 % For example QRS complexes at least 8 ms and gap between them at least 50 ms
 fs = DATA.ECG.orig.samplF/1000; % sampling frequency in ms^-1
 length0 = 30;
 length1 = 8;
 condition = [zeros(1,round(fs*length0)),ones(1,round(fs*length1))]; 
 % Now find all positions in the signal that fulfil the condition
 idx = strfind(aboveThr,condition)+round(fs*length0);
 % now it is possible to find maxima in the 20 ms portions of signal
 % following the start of regions of interest (roi)
 roi = round(fs*20);
 DATA.QRS.amplitude = zeros(1,numel(idx));
 DATA.QRS.time = zeros(1,numel(idx));
 waitbar(0.3);
 
 nidx = numel(idx);
 trailingzeros = zeros(1,roi);
 signal2 = [DATA.ECG.forAnalysis.signal,trailingzeros];
 for i=1:nidx
     [m,ind] = max(signal2(idx(i):idx(i)+roi));
     DATA.QRS.amplitude(i) = m;
     DATA.QRS.time(i) = DATA.ECG.orig.time(ind) + DATA.ECG.orig.time(idx(i));    
%      waitbar(0.4 + 0.6*i/nidx);
 end 
 
 if showQRSdetection
     f2 = figure;
     s1 = subplot(4,1,1,'units','normalized','position',[0,0.75,1,0.25]);
     plot(DATA.ECG.orig.time,DATA.ECG.forAnalysis.signal/ max(abs(DATA.ECG.forAnalysis.signal)),...
         'linewidth',3);
     hold on;
     plot(DATA.ECG.orig.time,DATA.ECG.BPfiltered.signal);
     hold on;
     scatter(DATA.QRS.time,DATA.QRS.amplitude/ max(abs(DATA.ECG.forAnalysis.signal)));
     s2 = subplot(4,1,2,'units','normalized','position',[0,0.5,1,0.25]);
     plot(DATA.ECG.orig.time,DATA.ECG.squared.signal);
     s3 = subplot(4,1,3,'units','normalized','position',[0,0.25,1,0.25]);
     plot(DATA.ECG.orig.time,DATA.ECG.movMax.signal);hold on;
     plot(DATA.ECG.orig.time,DATA.ECG.movAver.signal);
     linkaxes([s1,s2,s3],'x');
 end
 close(w);
 replot('data');
 calculateHR();
 % Enable manual editing button
 enableButtons([but_editQRSenable,but_ExportQRStimeCsv,...
     but_PQRSTaverager,inputNumOfAver],'on');
 
 %     Show QRS aligned at R-peak maximum if user asked for 3D plot
    if chck3Dplot.Value
        name = fileIn;
        time = DATA.ECG.forAnalysis.time;%time axis
        ecg = DATA.ECG.forAnalysis.signal;%ecg amplitude
        qrsTimes = DATA.QRS.time;%moments of detected R-peak maximums
        leftGapMS = 70; %signal preceeding R, milliseconds
        rightGapMS = 110; %signal following R, milliseconds
        samplingF = DATA.ECG.forAnalysis.samplF;
        n_th = 1; % plot only every n-th QRS
        timeJump = []; % in milliseconds, if timeJump is not empty then it will be used instead of n-th
        averHR = round(numel(qrsTimes)*60000/(qrsTimes(end)-qrsTimes(1)),1);%average heart rate within inspected time range
        HR = [DATA.HR.time',DATA.HR.signal'];
        showAlignedQrs(name,time,ecg,qrsTimes,leftGapMS,rightGapMS,samplingF,...
            n_th,timeJump,averHR,HR);
    end
end

function loadQRS(~,~)
% Unfinished function, needs to be revised or completely rewritten
    global DATA
    global but_editQRSenable but_ExportQRStimeCsv but_PQRSTaverager inputNumOfAver

    Rpeaks = csvread('testData_R-times2.csv');
    DATA.QRS.time = Rpeaks(:,1);
    DATA.QRS.amplitude = nan(size(DATA.QRS.time));
    w = waitbar(0,'Loading QRS');
    for i = 1:numel(DATA.QRS.time)
        ind = find(DATA.ECG.forAnalysis.time == DATA.QRS.time(i));
        DATA.QRS.amplitude(i,1) = DATA.ECG.forAnalysis.signal(ind);
        waitbar(i/numel(DATA.QRS.time));
    end
    close(w);
     replot('data');
     % Enable manual editing button
     enableButtons([but_editQRSenable,but_ExportQRStimeCsv,...
         but_PQRSTaverager,inputNumOfAver],'on');
    
    DATA.HR.time = Rpeaks(:,1)';
    DATA.HR.signal = Rpeaks(:,2)';

    DATA.HR.signal = [NaN,DATA.HR.signal,NaN];
    DATA.HR.time = [DATA.ECG.forAnalysis.time(1),DATA.HR.time,DATA.ECG.forAnalysis.time(end)];

    % Plot heart rate
    chooseSubplot('','','sp3','HR');
    replot('data');
%     replot('x');
    moveThroughSignal('','','autoY');
    
    % Activate buttons
    enableButtons(subplotSelectionGroup.Children(1),'on');
    enableButtons(but_recalculateHR,'off');
    set(sp3, 'ButtonDownFcn',{@selectInAxes,sp3});
    set(sp3.Children, 'ButtonDownFcn',{@selectInAxes,sp3});   
end

function calculateHR(~,~)
    global DATA subplotSelectionGroup but_recalculateHR sp3
    

    QRSs = DATA.QRS.time;
    
    % Remove points with nonsense values due to manualy deleted signal
    % The information is stored in nanVector    
    values = ~isnan(DATA.ECG.forAnalysis.nanVector);% ones for values, zeros for NaN
    % End indexes of nan regions in nan vector
    endIdx = find((diff(values)==1));
    excludedQRS = [];
    if ~isempty(endIdx)
        % recalculate to absolute time
        ends = DATA.ECG.forAnalysis.time(endIdx);
        for i=1:numel(ends) %for all deleted regions
          % Find first QRS value lying on the right from NaN
            firsRightNeigbour = find((QRSs - ends(i))>0, 1 );
            excludedQRS = [excludedQRS,firsRightNeigbour];
        end
    end
    excludedQRS(excludedQRS==1)=[];
    % Calculate heart rate from all QRS detections
    DATA.HR.signal = 60000 ./ diff(QRSs);
    % And now exclude those calculated from excluded QRS
    DATA.HR.signal(excludedQRS-1) = [NaN];
    DATA.HR.time = DATA.QRS.time(2:end);
    DATA.HR.time(excludedQRS - 1) = [NaN];

    % For plotting resons add first and last point NaN
    DATA.HR.signal = [NaN,DATA.HR.signal,NaN];
    DATA.HR.time = [DATA.ECG.forAnalysis.time(1),DATA.HR.time,DATA.ECG.forAnalysis.time(end)];
    
    % Plot heart rate
    chooseSubplot('','','sp3','HR');
    replot('data');
    replot('x');
    moveThroughSignal('','','autoY');
%     return focus back to ECG
    chooseSubplot('','','sp1','forAnalysis');   
    
    % Activate buttons
    enableButtons(subplotSelectionGroup.Children(1),'on');
    enableButtons(but_recalculateHR,'off');
    set(sp3, 'ButtonDownFcn',{@selectInAxes,sp3});
    set(sp3.Children, 'ButtonDownFcn',{@selectInAxes,sp3});
end

function PQRSTaverager(~,~)
    disp('PQRST Averager started');
    global DATA subplotSelectionGroup inputNumOfAver inputNumOfAverDef
    global but_ExportAverQRScsv fileIn chck3Dplot
    global but_PQRSTaverager cancelAveraging but_cancel
    
    cancelAveraging = 0;
    enableButtons(but_cancel,'on');
    enableButtons(but_PQRSTaverager,'off');
        
    % Averaging n-times, get value from editable field
    n = get(inputNumOfAver,'string');
    n = round(str2num(n));

    if isempty(n) || n < inputNumOfAverDef
        n = inputNumOfAverDef;
        set(inputNumOfAver,'string',num2str(inputNumOfAverDef));
    end
    if n > numel(DATA.QRS.time) % if requested number of averages is bigger than number of QRS, average all
        n = numel(DATA.QRS.time);
    end
    
    if n == 1 %if no averaging is requested then just copy actual ECG signal into averaged signal
        DATA.ECG.averQRS.signal = DATA.ECG.forAnalysis.signal;        
    else   
        % left and right neighbourhood of R-peak (as fraction of 1,
        % later will be estimated for each QRS in real samples)
        lnghbr = 0.41;%5/12; 
        rnghbr = 1 - lnghbr;

        % prepare empty signal of ECG with averaged QRS
        DATA.ECG.averQRS.signal = NaN(1,numel(DATA.ECG.forAnalysis.time));

        % show waitbar
        w = waitbar(0,['Averaging each ', num2str(n),' neighbouring PQRST complexes']);
        w.CloseRequestFcn = '';

        cycles = numel(DATA.QRS.time)-floor(n/2)-ceil(n/2);
        tStart = tic;
        % through all QRS times (centers of averaging)
        for i=ceil(n/2):numel(DATA.QRS.time)-floor(n/2)
    %         if user presses Cancel button break the cycle
            if cancelAveraging == 1
                break
            end

            % indexes of QRS to be averaged        
            i1 = 1 + i - ceil(n/2);
            i2 = i1 + n - 1;

            % calculate real neighbourhood of QRS
            % first calculate indexes of QRS one before (if exists) and one
            % following (if exists) the averaged ones for estimation of the
            % shortest usable inter-R interval
            k1 = max(i1 - 1,1);
            k2 = min(i2 + 1,numel(DATA.QRS.time));
            % shortest inter-R time
            shortest = min(diff(DATA.QRS.time(k1:k2)));
    %         left and right neighbourhood in samples
            Lnghbr = floor(lnghbr * 0.001 * shortest * DATA.ECG.forAnalysis.samplF);
            Rnghbr = floor(rnghbr * 0.001 * shortest * DATA.ECG.forAnalysis.samplF);

            % now handle the special cases, first and last QRS, because they
            % might not have complete left or right neighbourhood
            % the easiest is to skip them from averaging
            % so, for all QRS to be averaged in one step except for first and
            % last
            i1 = max(i1,2);
            i2 = min(i2,numel(DATA.QRS.time)-1);
            % prepare empty table of signals to average
            averaged = NaN(i2 - i1 + 1, Lnghbr + Rnghbr);
            for j = i1:i2
                % get index of ECG signal sample corresponding to the R-peak
                sigIndR = getTimeIdxs(DATA.ECG.forAnalysis.time,DATA.QRS.time(j));
                tempSig = DATA.ECG.forAnalysis.signal(sigIndR-Lnghbr+1:sigIndR+Rnghbr);
                averaged(j-i1+1,:) = tempSig;
            end
            % add averaged QRS to DATA
            sigIndR = getTimeIdxs(DATA.ECG.forAnalysis.time,DATA.QRS.time(i));
            DATA.ECG.averQRS.signal(sigIndR-Lnghbr+1:sigIndR+Rnghbr) = mean(averaged,1);

            tElapsed = toc(tStart);
            tCycle = tElapsed/i;
            tTotal = tCycle * cycles;
            waitbar(i/cycles,w,[{['Averaging each ', num2str(n),' neighbouring PQRST complexes.']};...
                {['Remaining time ',datestr(seconds(tTotal - tElapsed),'HH:MM:SS')]}]);

        end
        w.CloseRequestFcn = 'closereq';
        close(w);
    end
    % Activate button and replot
    enableButtons(but_PQRSTaverager,'on');
    enableButtons(subplotSelectionGroup.Children(3),'on');
    enableButtons(but_ExportAverQRScsv,'on');
    cancelAveraging = 0;
    enableButtons(but_cancel,'off');
    chooseSubplot('','','sp1','PQRSaver');
    replot('data');
    
 %     Show QRS aligned at R-peak maximum if user asked for 3D plot
    if chck3Dplot.Value
        [~,name,~] = fileparts(fileIn);
        name = [name,'_aver'];
        time = DATA.ECG.forAnalysis.time;%time axis
        ecg = DATA.ECG.averQRS.signal;%ecg amplitude
        qrsTimes = DATA.QRS.time;%moments of detected R-peak maximums
        leftGapMS = 70; %signal preceeding R, milliseconds
        rightGapMS = 110; %signal following R, milliseconds
        samplingF = DATA.ECG.forAnalysis.samplF;
        n_th = 1; % plot only every n-th QRS
        timeJump = [];%10000; % in milliseconds, if timeJump is not empty then it will be used instead of n-th
        averHR = round(numel(qrsTimes)*60000/(qrsTimes(end)-qrsTimes(1)),1);%average heart rate within inspected time range
        HR = [DATA.HR.time',DATA.HR.signal'];    
        showAlignedQrs(name,time,ecg,qrsTimes,leftGapMS,rightGapMS,samplingF,...
            n_th,timeJump,averHR,HR);
    end
end

function cancelAverager(~,~)
    global cancelAveraging
    cancelAveraging = 1;
end

function averageAllSelectedPQRST(~,~,timeAxis,name)
    global viewedQRS3D f4
%     get axes objects in f4
    ax = findall(f4,'type','axes');
%     subplot 1 is las child
    sp1 = ax(3);
    sp2 = ax(2);
    
    xLims = sp1.XLim;
    yLims = sp2.YLim;
    averQRS = mean(viewedQRS3D,1); 
    HR = size(viewedQRS3D,1) / diff(yLims);
    
    evalQRS(timeAxis,averQRS,HR);
    
    f = figure;
    p1 = plot([timeAxis(1),timeAxis(end)],[0,0],'LineStyle',':',...
        'LineWidth',1.6,'Color',[1,0,0]);
    hold on
    p2 = plot(timeAxis,averQRS,...
    'color',[0,0,0],'LineWidth',2);

    axF = findall(f,'type','axes');
    axF(1).XLim = xLims;
    title({name,['Average of ',num2str(size(viewedQRS3D,1)),...
        ' P-QRS-T'],['In time interval ',num2str(yLims(1)),...
        ' - ',num2str(yLims(2)),' min']},'Interpreter','none');        
%     axis tight

%     add averaged QRS also into subplot 1 in fig f4
    hold(sp1,'on');
    plot(sp1,timeAxis,averQRS,...
    'color',[1,0,0.894],'LineWidth',2);
    hold(sp1,'off');
    
%     Saving of averaged PQRST data as csv, png and timetable
    [filename, pathname] = uiputfile('*','Save average QRS signal',...
        [name,'_averQRS_',...
        num2str(round(yLims(1),2)),'-',...
        num2str(round(yLims(2),2)),...
        'min']);
    if filename ~= 0
        csvwrite([pathname,'\',filename,'.csv'],[timeAxis',averQRS']);
        saveas(f,[pathname,'\',filename,'.png']);
        tt=timetable(milliseconds(timeAxis)',averQRS');
        
    end
end

function evalQRS(t,s,HR)
    return
    global viewedQRS3D sp2
    % t time
    % s signal amplitude of averaged P-QRS-T event with R-peak aligned at time 0
    % HR heart rate

    % This function should find important points of the event, such as
    % Pstart, Ppeak, Pend, Q, R, S, J, T and Tend
%%
    % Options
    % where to look for individual waves
    Pinterval = [-65,-20];
    Qinterval = [-15,0];
    Sinterval = [0,15];
    Jinterval = [0,20];
    Tinterval = [];% this is the most troublesome, probably heart rate would help to estimate it?
    % Because RR interval is composed of almost stable P-R and variable R-P
    % dependent on HR. There T should appear.
%%
    result = [];
    
    % remove potential NaNs from data
    t(isnan(s))=[];
    s(isnan(s))=[];

    % check sampling rate, if too low, upsample
    si = t(2)-t(1);
    if si>0.2 % if sampling interval is bigger than 0.2 ms
        t2 = t(1):0.1:t(end);
        s=interp1(t,s,t2,'spline');
        t=t2;
    end
    % derivatives and other manipulated signals
    sDif = derivate(t,s);
    sDif2 = 10*derivate(t,sDif);% 2nd derivative
    sDif3 = 5*derivate(t,sDif2);% 3rd derivative
    sDifSqr = derivate(t,s.*s);% derivative of square of signal
    sDifCub = 0.001 * derivate(t,s.*s.*s);% derivative of cube of signal
    sDif2Sqr = derivate(t,sDifSqr);
%     frequency filtering
    filterF1 = designfilt('lowpassiir','FilterOrder',1, ...
        'HalfPowerFrequency',50,'DesignMethod','butter',...
        'SampleRate',1000/(t(2)-t(1)));
    sHP = filtfilt(filterF1,s);
    
% R peak
    R = [0,s(t==0)];% easy, by definition R is alligned at time 0
    result = [result;R];
    
% P peak
    idx = (t>=Pinterval(1)).*(t<=Pinterval(2));% select region of interest given in Options
    idx(idx==0)=NaN; % replace excluded regions with NaN, because min/max function indexes NaNs
    [amp,ind] = max(s .* idx);
    P = [t(ind),amp];
    result = [result;P];

% P start
    idx = (t>=P(1)-7) .* (t<=P(1)-2) .* (sDif>=0);
    idx(idx==0)=NaN;
%     [~,ind] = max(sDif3 .* idx);
    [~,ind] = min(sDif2Sqr .* idx);
    Pstart = [t(ind),s(ind)];
    result = [result;Pstart];
    
% P end
    idx = (t>=P(1)+2) .* (t<=P(1)+7) .* (sDif<=0);
    idx(idx==0)=NaN;
    [~,ind] = min(sDif2Sqr .* idx);
    Pend = [t(ind),s(ind)];
    IsolineIdx1 = ind;
    result = [result;Pend];
    
% Q
    idx = (t>=Qinterval(1)) .* (t<=Qinterval(2)) .* (sDif>=0);
    idx(idx==0)=NaN;
    [~,ind] = max(sDif3 .* idx);
    Q = [t(ind),s(ind)];
    result = [result;Q];
    IsolineIdx2 = ind;
    
% Isoline
    Isoline = mean(s(IsolineIdx1:IsolineIdx2));
    
% S
    idx = (t>=Sinterval(1)) .* (t<=Sinterval(2));% .* (sDif<=0);
    idx(idx==0)=NaN;
%     [~,ind] = min(sDif3 .* idx);
%     [~,ind] = min(sDif2Sqr .* idx);
    [~,ind] = min(s .* idx);
    S = [t(ind),s(ind)];
    result = [result;S];
    
% J
    idx = (t>=S(1)) .* (t<=Jinterval(2));
    idx(idx==0)=NaN;
    [~,ind] = max(sDif3 .* idx);
    J = [t(ind),s(ind)];
    result = [result;J];
    
% T
%     low-pass filter
    
    

    f1 = figure();
    a1 = axes(f1);
%     plot(a1,t,s);
    hold(a1,'on');
    plot(a1,t,s,'color','black','linewidth',2);
%     plot(a1,t,sDif);
%     plot(a1,t,sDif2);
%     plot(a1,t,sDif3);
%     plot(a1,t,sDif2Sqr);
%     plot(a1,t,sDifCub);
    plot(a1,t,sHP,'color','blue','linewidth',1);
    plot(a1,t,s-sHP,'color','red','linewidth',1);
    plot(a1,result(:,1),result(:,2),'o');
%     plot(a1,[t(1),t(end)],[Isoline,Isoline]);


    end

function res = derivate(t,s)
    % derivative of signal s along time t
    idxOdd = 1:2:numel(s);
    idxEven = 2:2:numel(s);

    sOdd = s(idxOdd);
    sEven = s(idxEven);

    sOddDif = diff(sOdd);
    sEvenDif = diff(sEven);

    if ~mod(numel(s),2) % numel of s is even
        sDif = nan(1,numel(s));
        sDif(idxEven(1:end-1)) = sOddDif;
        sDif(idxOdd(2:end)) = sEvenDif;
    else % numel of s is odd
        sDif = nan(1,numel(s));
        sDif(idxEven(1:end)) = sOddDif;
        sDif(idxOdd(2:end-1)) = sEvenDif(1:end);
    end
    res = sDif;
end

function showAlignedQrs(name,time,ecg,qrsTimes,leftGapMS,rightGapMS,...
    samplingF,n_th,timeJump,averHR,HR)
    %     Show plot of QRS elements aligned at R-peak maximum
%     [time;ecg] is the signal to plot (organized as 1 x X row)
%   qrsTimes is row of time points of R peaks
%   n_th means to plot every n-th QRS element

global mycolormap viewedQRS3D

%     show message about work in progress
    w = waitbar(0,'Work in progress');
    
%     prepare the final list of QRS times
    if ~isempty(timeJump) % if timeJump contains number of milliseconds to jump
%         then it will be used rather than n_th
        timeJumps = 0:timeJump:time(end);
        qrsTimes2 = nan(size(timeJumps));
        
        for i = 1:numel(qrsTimes2)
%             find the QRS closest to the actual time jump
            t2 = abs(qrsTimes - timeJumps(i));
            [~,ind] = min(t2);
            qrsTimes2(i) = qrsTimes(ind);
        end
    else
        ind = 1:n_th:numel(qrsTimes);
        qrsTimes2 = qrsTimes(ind);
    end
    
    leftGap = ceil(leftGapMS * samplingF/1000);% in samples
    rightGap = ceil(rightGapMS * samplingF/1000);% in samples
    timeAxis = -leftGap:1:rightGap;
    timeAxis = 1000 * timeAxis/samplingF; % in milliseconds
    
    qrs3D = nan(numel(qrsTimes2),numel(timeAxis));
    
%     go through the final list of qrs and align them at R peaks (time 0)
    for i = 1:numel(qrsTimes2)
%         Find R-peak, take some signal preceeding it (given by leftGap variable)
%           and some following (rightGap) and join them, complement with NaN if
%           needed        
        ind = find(time == qrsTimes2(i));       
        ind1 = max(ind - leftGap,1);
        ind2 = min(ind + rightGap,numel(ecg));
        ecg2 = [nan(1,leftGap-(ind-ind1)),ecg(ind1:ind2),nan(1,rightGap-(ind2-ind))];
        if size(ecg2,2) == 0
            continue
        end
        qrs3D(i,:) = ecg2 * 1000;% to milivolts
       
%         c = i * 0.65 / numel(qrsTimes2);
%         p = plot(gca,timeAxis,ecg2,'color',[c,c,c]);
%         hold on;
    end
    
%     calculate heart rate running average
    averagingTime = 10000; % averaging time window in miliseconds
    resampleTo = samplingF/10; % new samplinf freq for HR, downsampling helps speed
    timestep = 1000/resampleTo; % in milliseconds
%     remove NaN from HR
    nans = isnan(HR(:,1)) + isnan(HR(:,2));
    HR(logical(nans),:) = [];
    HRinterpTime = (HR(1,1):timestep:HR(end,1))';
    HRinterp = interp1(HR(:,1),HR(:,2),HRinterpTime);
    HRinterp = movmean(HRinterp,0.001 * averagingTime * resampleTo);

    close(w);
    
%   plot PQRST signals
    global f4
    f4 = figure('units','pixels','position',[300,0,900,1100]);

    s1 = subplot('position',[0.1,0.7,0.6,0.25]);
    plot(s1,[timeAxis(1),timeAxis(end)],[0,0],'LineStyle',':',...
        'LineWidth',1.6,'Color',[1,0,0]);
    hold on
    plot(s1,timeAxis,qrs3D, 'color',[0,0,0]);
    hold off
    [~,name,~] = fileparts(name);
%     titl = [name,', Average HR: ',num2str(averHR),' beats/min'];
    title([name,', Average HR: ',num2str(averHR),' beats/min'],'Interpreter','none');
    set(gca, 'XLimSpec', 'Tight');
    xticks([]);
    ylabel('Amplitude (mV)');
    
%   plot PQRST 3D colormap
    s2 = subplot('position',[0.1,0.1,0.6,0.6]);
    surf(timeAxis,qrsTimes2/60000,qrs3D,'LineStyle','-','EdgeColor','none','FaceColor','flat');
    view(0,90);
    colormap(mycolormap);
    caxis([-5.5,22]);
    colorbar('East');  
    axis tight
    s2.YLim(1) = 0;
    s2.Color = [0.85,0.85,0.85];
    xlabel('Time (ms)');
    ylabel('Time (min)');
    zlabel('Amplitude (mV)');
    linkaxes([s1,s2],'x');

    viewedQRS3D = qrs3D; 
    
%   plot heart rate
    s3 = subplot('position',[0.7,0.1,0.26,0.6]);
    plot(s3,HR(:,1)/60000,HR(:,2),'LineWidth',1.6,'Color',[0.7,0.7,0.7]);
    hold on
    plot(s3,HRinterpTime/60000,HRinterp,'LineWidth',1.0,'Color',[0,0,0]);
    axis tight
%     xticks([]);
    ylabel('HR (beats/min)');
    s3.XLim = s2.YLim;
%     s3.YLim = [200,740];
    s3.XAxisLocation = 'top';
    view(270,90);
    
%   Add button for adapting axis to current selection
    but_adaptAxes = uicontrol(f4,'style','pushbutton','string','Adapt axes to 3D plot', 'units','normalized',...
        'position',[0.75,0.9,0.2,0.07],'fontsize',11,'callback',{@adaptAxes,...
        timeAxis,qrs3D,qrsTimes2,name});
%   Add button for averaging
    but_averageQRS = uicontrol(f4,'style','pushbutton','string','Average PQRST', 'units','normalized',...
        'position',[0.75,0.8,0.2,0.07],'fontsize',11,'callback',{@averageAllSelectedPQRST,timeAxis,name});    
           
%     save figure as bitmap and matlab fig
    [FILENAME, PATHNAME, FILTERINDEX] = uiputfile('*.png', 'Save image as',[name,'_QRSaligned.png']);
    if ~isequal(FILENAME,0)
        saveas(f4,[PATHNAME,FILENAME]);
    end
%     [FILENAME, PATHNAME, FILTERINDEX] = uiputfile('*.fig', 'Save image as',[name,'_QRSaligned.fig']);
%     if ~isequal(FILENAME,0)
%         saveas(f4,[PATHNAME,FILENAME]);
%     end

% %     save figure automatically and close it
%     saveas(f4,[name,'_QRSaligned.png']);
%     saveas(f4,[name,'_QRSaligned.fig']);
%     close(f4);
          
end

function adaptAxes(~,~,timeAxis,qrs3D,qrsTimes2,name)
    global f4 viewedQRS3D
%     get axes objects
    ax = findall(f4,'type','axes');
%     subplot 1 is las child, subplot 3 is first 
    sp1 = ax(3);
    sp2 = ax(2);
    sp3 = ax(1);
    
    xLims = sp2.XLim;
    yLims = sp2.YLim;
    sp3.XLim = yLims;

%     Replot subplot 1 so that number of shown signals corresponds to
%     selected portion of subplot 2
    hold(sp1,'off');
    plot(sp1,[timeAxis(1),timeAxis(end)],[0,0],'LineStyle',':',...
        'LineWidth',1.6,'Color',[1,0,0]);
    hold(sp1,'on');
%     get only those GRS signals within displayed time limits
    qrsTimes2 = qrsTimes2/60000;%to minutes
    ind1 = qrsTimes2 >= yLims(1);
    ind2 = qrsTimes2 <= yLims(2);
    ind3 = logical(ind1 .* ind2);
    viewedQRS3D = qrs3D(ind3,:);
%     and plot only these
    plot(sp1,timeAxis,viewedQRS3D, 'color',[0,0,0]);
    sp1.XLim = xLims;
    title(sp1,name,'Interpreter','none');
% %     Calculate new average HR based on selected portion of signal
%     global DATA
%     qrsTimesOrig = DATA.QRS.time/60000 ;%to minutes
%     qrsTimesViewedInd = qrsTimesOrig >= yLims(1) & qrsTimesOrig <= yLims(2);
%     qrsTimesViewed = qrsTimesOrig(qrsTimesViewedInd);
%     if numel(qrsTimesViewed)<2 || qrsTimesViewed(end)==qrsTimesViewed(1)
%         title(sp1,[name,', Average HR: not available'],'Interpreter','none');
%     else
%         averHR = round(numel(qrsTimesViewed)/(qrsTimesViewed(end)-qrsTimesViewed(1)),1);
%         title(sp1,[name,', Average HR: ',num2str(averHR),' beats/min'],'Interpreter','none');
%     end
end

function invert(~,~)
    global DATA current but_unfilter
    % inverts polarity of signals, all signals should be inverted? Or only
    % the signal for analysis?
    
    if isequal(current.subplotLine,'forAnalysis')
        DATA.ECG.forAnalysis.signal = -1 * DATA.ECG.forAnalysis.signal;
        current.signal = DATA.ECG.forAnalysis.signal;
        replot('data');
        current.inverted = mod(current.inverted + 1,2);
    end
    
    enableButtons(but_unfilter,'on');
end

function selectInAxes(~,e,sp)
% allows selection of interval in f1 figure with mouse left and right click
    global current sp1;

    if e.Button==1
        current.selection(1) = e.IntersectionPoint(1,1);
        if e.IntersectionPoint(1,1) > current.selection(2)
            current.selection(2) = NaN;
            set(sp1.Children(end),'XData',[NaN,NaN],'YData',[NaN,NaN]);
        end
    elseif e.Button == 3
        current.selection(2) = e.IntersectionPoint(1,1);
        if e.IntersectionPoint(1,1) < current.selection(1)
            current.selection(1) = NaN;
            set(sp1.Children(end),'XData',[NaN,NaN],'YData',[NaN,NaN]);
        end
    end
    if ~isnan(sum(current.selection))
        set(sp1.Children(end),'XData',current.selection,'YData',[0,0]);
    end
end

function applyToSelection(~,~,whatToDo)
% selects part of the current time in the current figure and turns current signal 
% in the selected interval to NaN, 0, or whatever
    global DATA current
    
    if isequal(whatToDo,'zoomIn')
        current.Xlim = current.selection;
        replot('x');
    elseif isequal(current.subplotLine,'forAnalysis') && ~isnan(sum(current.selection))
        idx = getTimeIdxs(DATA.ECG.forAnalysis.time,current.selection);
        switch whatToDo
            case 'zero'
                DATA.ECG.forAnalysis.signal(idx(1):idx(2)) = 0;
                DATA.ECG.forAnalysis.nanVector(idx(1):idx(2)) = NaN;
                current.signal = DATA.ECG.forAnalysis.signal;
                replot('data');
            case 'restore'
                if current.inverted
                    DATA.ECG.forAnalysis.signal(idx(1):idx(2)) = -1 * DATA.ECG.orig.signal(idx(1):idx(2));
                else
                    DATA.ECG.forAnalysis.signal(idx(1):idx(2)) = DATA.ECG.orig.signal(idx(1):idx(2));
                end
                DATA.ECG.forAnalysis.nanVector(idx(1):idx(2)) = 1;
                current.signal = DATA.ECG.forAnalysis.signal;
                replot('data');
            case 'select'
                tempSignal = DATA.ECG.forAnalysis.signal(idx(1):idx(2));
                tempNan = DATA.ECG.forAnalysis.nanVector(idx(1):idx(2));
                DATA.ECG.forAnalysis.signal(1:end) = 0;
                DATA.ECG.forAnalysis.nanVector(1:end) = NaN;
                DATA.ECG.forAnalysis.signal(idx(1):idx(2)) = tempSignal;
                DATA.ECG.forAnalysis.nanVector(idx(1):idx(2)) = tempNan;
                current.signal = DATA.ECG.forAnalysis.signal;
                replot('data');
        end
    end
end

function moveThroughSignal(~,~,movement)
    global current
    
    % get the axis values from the current plot  
    tempXrange = get(current.subplot,'XLim');
    tempYrange = get(current.subplot,'YLim');
    
    sig = current.signal;
    time = current.time;
    % recalculate the requested parameter to a temporary value
    switch movement
        case '<'
            tempXrange = tempXrange - 0.14 * abs(diff(tempXrange));
        case '<<'
            tempXrange = tempXrange - 0.9 * abs(diff(tempXrange));
        case '>'
            tempXrange = tempXrange + 0.14 * abs(diff(tempXrange));
        case '>>'
            tempXrange = tempXrange + 0.9 * abs(diff(tempXrange));
        case 'x+'
            dif = 0.3 * abs(diff(tempXrange));
            tempXrange(1) = tempXrange(1) + dif;
            tempXrange(2) = tempXrange(2) - dif;
        case 'x-'
            dif = 0.3 * abs(diff(tempXrange));
            tempXrange(1) = tempXrange(1) - dif;
            tempXrange(2) = tempXrange(2) + dif;
        case 'y+'
            dif = 0.2 * abs(diff(tempYrange));
            tempYrange(1) = tempYrange(1) + dif;
            tempYrange(2) = tempYrange(2) - dif;
        case 'y-'
            dif = 0.2 * abs(diff(tempYrange));
            tempYrange(1) = tempYrange(1) - dif;
            tempYrange(2) = tempYrange(2) + dif;
        case 'v'
            tempYrange = tempYrange + 0.14 * abs(diff(tempYrange));
        case '^'
            tempYrange = tempYrange - 0.14 * abs(diff(tempYrange));
        case 'autoY'
            idx = getTimeIdxs(time,get(current.subplot,'XLim'));
            n = min(sig(idx(1):idx(2)));
            m = max(sig(idx(1):idx(2)));
            if m ~= n
                tempYrange(1) = n - 0.1*(m-n);
                tempYrange(2) = m + 0.1*(m-n);
            end
        case 'xStart'
            tempXrange(2) = abs(diff(tempXrange));
            tempXrange(1) = 0;      
        case 'xEnd'
            tempXrange(1) = time(end) - abs(diff(tempXrange));
            tempXrange(2) = time(end);
        case 'xAll'
            tempXrange(1) = 0;
            tempXrange(2) = time(end);
    end
    
    % check that the temporary values satisfy conditions (signal limits,
    % other?)
    if tempXrange(1) < time(1)      
        if ~contains(movement,'x')% if not zooming in or out
            tempXrange(2) = abs(diff(tempXrange));
        end
        tempXrange(1) = 0;
    end
    if tempXrange(2) > time(end)       
        if ~contains(movement,'x')% if not zooming in or out
            tempXrange(1) = time(end) - abs(diff(tempXrange));
        end
        tempXrange(2) = time(end);
    end
%     if abs(diff(getTimeIdxs(time,tempXrange))) < 60
%         % should the number of points on x-axis drop below 60
%         return %do nothing
%     end    
    
    % execute the changes
%     set(ax, 'XLim',tempXrange,'YLim',tempYrange);
    current.Xlim = tempXrange;
    current.Ylim = tempYrange;
    replot('x');
    replot('y');
end

function selectFile(~,~)
    global fileIn pathF DATA
    [f,p] = uigetfile('*.mat', 'Open Matlab (.mat) data file exported from Labchart', 'MultiSelect', 'off');
    if f == 0
        disp('No file selected');
        if isnan(DATA.ECG.orig.signal)
            showMessage('No file opened','red');
        end
        return
    else
        fileIn = f;
        pathF = p;
        openFile([p,f]);
    end
end

function setchannel(h,e,chtitles)
    global ECGch BRch
    global ecgPopup brPopup
    ECGch = get(ecgPopup,'value');
    BRch = get(brPopup,'value');
    
    % in case 'None' is selected from the list
    % implement some way to handle data and plots...
    if ECGch > numel(chtitles)
        ECGch = NaN;
    end
    if BRch > numel(chtitles)
        BRch = NaN;
    end

	closeWind(h,e);
end

function closeWind(h,e)
    close(h.Parent);
end

function openFile(~)
    global fileIn pathF ECGch BRch
    global DATA f1 current sp1 sp2 sp3 header dat
    global navButGroup selectionToolGroup editingToolGroup analysisToolGroup
    global subplotSelectionGroup butSelectFile but_ExportSelEditECGcsv
    global ecgPopup brPopup filterOnLoad filtersGroup BPlow BPhigh
    disp('Opening file');
    disp([pathF fileIn]);
    resetGlobals();
    enableButtons('all','off');
    enableButtons(butSelectFile,'on');
    % Load .mat file and distribute it to global structure DATA
    % corresponding to ECG and breath signals
    dat = load([pathF fileIn]);
    
    % Here it should be checked whether file contains more channels and which
    numOfCh = numel(dat.titles);
    
    %% this part, if uncommented, asks user to select channels
    %     f4 = figure('windowstyle', 'normal','units','normalized','position',[0.3,0.3,0.4,0.4]);
    %     uicontrol(f4,'style','text','string','Select which channel is ECG and which is signal of breath:',...
    %         'fontsize',16,'units','normalized','position',[0,0.7,1,0.3]);
    %     uicontrol(f4,'style','text','string','ECG         Breath',...
    %         'fontsize',32,'units','normalized','position',[0,0.5,1,0.3]);
    %     chtitles = string(dat.titles)';
    % 
    %     ecgPopup = uicontrol(f4,'style','popupmenu','string',[chtitles,'None'],...
    %         'units','normalized', 'position',[0.1,0.3,0.35,0.2],'fontsize',16);
    %     brPopup = uicontrol(f4,'style','popupmenu','string',[chtitles,'None'],...
    %         'units','normalized', 'position',[0.55,0.3,0.35,0.2],'fontsize',16);
    %     set(ecgPopup,'value',1);
    %     set(brPopup,'value',size(chtitles,2));
    %     ok = uicontrol(f4,'style','pushbutton','string','OK', 'units','normalized',...
    %         'position',[0.3,0.2,0.4,0.2],'fontsize',20,'callback',{@setchannel,chtitles});
    %     waitfor(f4);
    %%
    
    if isempty(ECGch)
        messageText = 'No ECG signal ';
    else
        DATA.ECG.orig.signal = dat.data(1,dat.datastart(ECGch):dat.dataend(ECGch));
        DATA.ECG.orig.samplF = dat.samplerate(ECGch);
        DATA.ECG.orig.time = [0:numel(DATA.ECG.orig.signal)-1] * 1000/DATA.ECG.orig.samplF;
        DATA.ECG.forAnalysis.signal = DATA.ECG.orig.signal;
        DATA.ECG.forAnalysis.time = DATA.ECG.orig.time;
        DATA.ECG.forAnalysis.nanVector = ones(size(DATA.ECG.forAnalysis.time));
        DATA.ECG.forAnalysis.samplF = DATA.ECG.orig.samplF;
        if filterOnLoad.Value  
%             % Band-pass filter if checked
            filterBP([],[],'BPfilter');
        end
    end
    if isempty(BRch)
        messageText = 'No breath signal ';
    else
        DATA.breath.orig.signal = dat.data(1,dat.datastart(BRch):dat.dataend(BRch));
        DATA.breath.orig.samplF = dat.samplerate(BRch);
        DATA.breath.orig.time = [0:numel(DATA.breath.orig.signal)-1] * 1000/DATA.breath.orig.samplF;
    end
        
    if isempty(ECGch) && isempty(BRch)
        showMessage('No data loaded.','red');
        return
    end
    
    cd(pathF);
%     DATA.comments = [num2cell(dat.com(:,3)),cellstr(dat.comtext)];
        
    % Handle figure 
    current.figure = f1;
    
    % Handle subplot 3
    set(sp3,'YLimMode','manual');
    chooseSubplot('','','sp3','HR');
    replot('data');
    
    % set the current signal to breath raw data and plot it
    chooseSubplot('','','sp2','BreathOrig');
    replot('data');
    % Show full range of x-axis
    moveThroughSignal('','','xAll');
    set(sp2,'YLimMode','manual');
    moveThroughSignal('','','autoY');
    
    % Clear plotted interval and QRS
    set(sp1.Children, 'XData',NaN,'YData',NaN);
    
    % set the current signal to ECG forAnalysis and plot it
    chooseSubplot('','','sp1','forAnalysis');
    replot('data');
    chooseSubplot('','','sp1','forAnalysis');
    replot('data');
    chooseSubplot('','','sp1','forAnalysis');
    replot('data');
    set(sp1,'YLimMode','manual');
    moveThroughSignal('','','autoY');
    
    % Activate buttons
    enableButtons([navButGroup.Children;selectionToolGroup.Children;...
        editingToolGroup.Children(end);...
        analysisToolGroup.Children(end);subplotSelectionGroup.Children([2,4,5])],'on');
    enableButtons(but_ExportSelEditECGcsv,'on');
    enableButtons(filtersGroup.Children,'on');
    
    % Make the axes and plot respond to button down by selecting an interval
    set(sp1.Children, 'ButtonDownFcn',{@selectInAxes,sp1});
    set(sp1, 'ButtonDownFcn',{@selectInAxes,sp1});
    set(sp2.Children, 'ButtonDownFcn',{@selectInAxes,sp2});
    set(sp2, 'ButtonDownFcn',{@selectInAxes,sp2});
    
    % Show messages
    set(header,'string',fileIn);

end

function filterBP(~,~,typeOf)
    global DATA BPlow BPhigh current sp1 but_unfilter
    
%     Band-pass filter the original data into data for analysis
%     needs to check low and high limits somehow and find a way to restore
%     original data
    if isequal(typeOf,'unfilter')
%         restore original data
        DATA.ECG.forAnalysis.signal = DATA.ECG.orig.signal;
        enableButtons(but_unfilter,'off');
    elseif isequal(typeOf,'BPfilter')
%        do band-pass filter
        % first check validity of inputs from user
        fL = str2num(BPlow.String);
        fH = str2num(BPhigh.String);
        err = numel(fL)>1 || numel(fH)>1;
        if isempty(fL) || isempty(fH) || err
            showMessage('Incorrect input','red');
            BPlow.String = 'Err';
            BPhigh.String = 'Err';
            return
        end
        Wn=[fL fH]*2/DATA.ECG.orig.samplF;               % cutt off based on fs
        N = 3;                                           % order of 3 less processing
        [a,b] = butter(N,Wn);                            % bandpass filtering
        DATA.ECG.forAnalysis.signal = filtfilt(a,b,DATA.ECG.orig.signal);
        DATA.ECG.forAnalysis.signal = filtfilt(a,b,DATA.ECG.forAnalysis.signal);
        enableButtons(but_unfilter,'on');
    end
    applyToSelection([],[],'select');
    current.subplot = sp1;
    current.subplotLine = 'forAnalysis';
    current.signal = DATA.ECG.forAnalysis.signal;
    replot('data');
end

function replot(type)
    % Plotting current content, ranges and design of graphs
    global current DATA sp1 sp2 sp3
    
    switch type
        case 'data'
            % In case it is asked to replot data lines and points
            sp = current.subplot;
            
            if sp == sp1
                set(sp.Children(1),'XData',current.time,'YData',current.signal);
                if isequal(current.subplotLine,'forAnalysis')
                    set(sp.Children(1),'color',[0,0.25,0.6]);
                elseif isequal(current.subplotLine,'PQRSaver')
                    set(sp.Children(1),'color',[0.5,0.5,0]);
                else
                    set(sp.Children(1),'color','black');
                end
                set(sp.Children(2),'XData',DATA.QRS.time,'YData',DATA.QRS.amplitude);
            else
                set(sp.Children(1),'XData',current.time,'YData',current.signal);
            end
        case 'x'
            % In case it is asked to move or zoom on x axis
            set([sp1 sp2 sp3],'XLim',current.Xlim);
        case 'y'
            set(current.subplot,'YLim',current.Ylim);
        case 'active'
            % Make current subplot styled as active
            set([sp1,sp2,sp3],'linewidth',1,'Color',[0.95,0.95,0.95]);
            set(current.subplot,'linewidth',2.5, 'Color',[1,1,1]);
    end 
    
end

function exportCSV(~,~,m)
    global DATA current fileIn pathF inputNumOfAver
    switch m
        case 'selectedEditedECGcsv'           
            selectionExists = ~logical(isnan(current.selection(1,1)) + isnan(current.selection(1,2)));
            if selectionExists
                idx = logical(DATA.ECG.forAnalysis.time > current.selection(1,1));
                idx = idx .* logical(DATA.ECG.forAnalysis.time < current.selection(1,2));
                idx = find(idx);
                datForExport = [DATA.ECG.forAnalysis.time(idx)',DATA.ECG.forAnalysis.signal(idx)'];
                if size(datForExport,1)>1048576
                    showMessage('Waiting for user response...',[0.5 0.5 0]);
                    answer = questdlg({'More than 1048576 time points selected.';...
                        'This may result in csv file that will not open';...
                        'in MS Excel table';' ';'Export anyway?'},...
                        'Large file',...
                        'Yes','No','Yes');
                    if ~isequal(answer,'Yes')
                        showMessage('Export canceled.','red');
                        return
                    end
                end
                [~,defName,~]=fileparts(fileIn);
                defName = [defName,'_selection'];
                [file,path] = uiputfile('*.csv', 'Save selection of edited ECG signal as csv', [defName,'.csv']);
                
                if ~isequal(file,0)
                    showMessage('Exporting...',[0.5 0.5 0]);
                    msg = msgbox('Exporting...');
                    dlmwrite([path,file],datForExport,'delimiter',',','precision',15);
                    showMessage('Export done',[0 0.5 0.1]);
                    close(msg);
                end
            else
                showMessage('No signal selected, export canceled', 'red');
                return
            end
        case 'QRStimes'
            datForExport = NaN(numel(DATA.QRS.time),2);
            datForExport(:,1) = DATA.QRS.time';
            datForExport(2:end,2) = DATA.HR.signal(1,2:numel(DATA.QRS.time))';
            [~,defName,~]=fileparts(fileIn);
            defName = [defName,'_R-times'];
            [file,path] = uiputfile('*.csv', 'Save times of R peaks as csv', [defName,'.csv']);
            dlmwrite([path,file],datForExport,'delimiter',',','precision',15);
            showMessage('Export done',[0 0.5 0.1]);
        case 'averQRS'
            selectionExists = ~logical(isnan(current.selection(1,1)) + isnan(current.selection(1,2)));
            if selectionExists
                idx = logical(DATA.ECG.forAnalysis.time > current.selection(1,1));
                idx = idx .* logical(DATA.ECG.forAnalysis.time < current.selection(1,2));
                idx = find(idx);
                datForExport = [DATA.ECG.forAnalysis.time(idx)',DATA.ECG.averQRS.signal(idx)'];
                if size(datForExport,1)>1048576
                    showMessage('Waiting for user response...',[0.5 0.5 0]);
                    answer = questdlg({'More than 1048576 time points selected.';...
                        'This may result in csv file that will not open';...
                        'in MS Excel table';' ';'Export anyway?'},...
                        'Large file',...
                        'Yes','No','Yes');
                    if ~isequal(answer,'Yes')
                        showMessage('Export canceled.','red');
                        return
                    end
                end
                [~,defName,~]=fileparts(fileIn);
                n = get(inputNumOfAver,'string');
                defName = [defName,'_QRSaverOf',n];
                [file,path] = uiputfile('*.csv', 'Save ECG with averaged QRS as csv', [defName,'.csv']);
                
                if ~isequal(file,0)
                    showMessage('Exporting...',[0.5 0.5 0]);
                    msg = msgbox('Exporting...');
                    dlmwrite([path,file],datForExport,'delimiter',',','precision',15);
                    showMessage('Export done',[0 0.5 0.1]);
                    close(msg);
                end
            else
                showMessage('No signal selected, export canceled', 'red');
                return
            end

    end
disp('Done.');
end

function res = getTimeIdxs(time,timePoints)
% Returns indexes of time elements nearest to timePoints elements
    res = zeros(size(timePoints));
    for i=1:numel(timePoints)
        [~,res(i)] = min(abs(time - timePoints(i)));     
    end
end

function resetGlobals()
% Initiates global variables on start or whenever new file is opened.
    global DATA current
    % Currently active handles and values of variables related to plotting
    current.figure = NaN;
    current.subplot = NaN;
    current.subplotLine = NaN;
    current.signal = NaN; % signal currently analysed or edited
    current.time = NaN;
    current.samplF = NaN;
    current.Xlim = [NaN,NaN];
    current.Ylim = [NaN,NaN];
    current.selection = [NaN,NaN]; % interval (ms) selected on the current time axis
    current.inverted = 0; %whether the DATA.ECG.forAnalysis.signal has been inverted
    
    % The main data structure with original and edited signal as well as
    % results of analysis
    DATA.comments = [];
    DATA.ECG.orig.samplF = NaN;
    DATA.ECG.orig.time = NaN;
    DATA.ECG.orig.signal = NaN;
    DATA.ECG.forAnalysis.signal = NaN;
    DATA.ECG.forAnalysis.time = NaN;
    DATA.ECG.forAnalysis.nanVector = [1];
    DATA.ECG.averQRS.signal = NaN;
    DATA.breath.orig.samplF = NaN;
    DATA.breath.orig.signal = NaN;
    DATA.breath.orig.time = NaN;
    DATA.QRS.time = NaN;
    DATA.QRS.amplitude = NaN;
    DATA.HR.signal = NaN;
    DATA.HR.time = NaN;
end

function showMessage(text,color)
    global message
    set(message,'string',text,'ForegroundColor',color);
end

function enableButtons(butt,action)
    if isequal(butt,'all')
        % If no specific button, disable all
        butt = findobj('style','pushbutton');
        butt = [butt;findobj('style','edit')];
    end
    set(butt,'enable',action);
end

function keyPress(~,event)
    global navButGroup selectionToolGroup analysisToolGroup
%     disp(event.Key);
%     disp(event.Modifier);
%     disp(event);
    
    switch event.Key
        case 'z' % zoom in selected portion of signal
%             check that corresponding button is enabled
            but = contains(get(selectionToolGroup.Children,'String'),'Zoom In (z)');
            but = selectionToolGroup.Children(but);
            if isequal(get(but,'Enable'),'on')      
                applyToSelection('','','zoomIn');
            end
        case 'a' % zoom out to see complete recording
            but = contains(get(navButGroup.Children,'String'),'All');
            but = navButGroup.Children(but);
            if isequal(get(but,'Enable'),'on')       
                moveThroughSignal('','','xAll');
            end
        case 'd' % delete selected portion of ecg
            but = contains(get(selectionToolGroup.Children,'String'),'Delete (d)');
            but = selectionToolGroup.Children(but);
            if isequal(get(but,'Enable'),'on')       
                applyToSelection('','','zero');
            end
        case 'delete' % alternative key for deleting
            but = contains(get(selectionToolGroup.Children,'String'),'Delete (d)');
            but = selectionToolGroup.Children(but);
            if isequal(get(but,'Enable'),'on')       
                applyToSelection('','','zero');
            end
        case 'rightarrow'
            but = contains(get(navButGroup.Children,'String'),'->');
            but = navButGroup.Children(but);
            if isequal(get(but,'Enable'),'on')
                if isequal(event.Modifier,{'control'})||isequal(event.Modifier,{'shift'})
                    moveThroughSignal('','','>>');
                else
                    moveThroughSignal('','','>');
                end
            end
        case 'leftarrow'
            but = contains(get(navButGroup.Children,'String'),'<-');
            but = navButGroup.Children(but);
            if isequal(get(but,'Enable'),'on') 
                if isequal(event.Modifier,{'control'})||isequal(event.Modifier,{'shift'})
                    moveThroughSignal('','','<<');
                else
                    moveThroughSignal('','','<');
                end
            end
        case 'add'
            but = contains(get(navButGroup.Children,'String'),'<+>');
            but = navButGroup.Children(but);
            if isequal(get(but,'Enable'),'on')
                moveThroughSignal('','','x+');
            end
        case 'subtract'
            but = contains(get(navButGroup.Children,'String'),'>-<');
            but = navButGroup.Children(but);
            if isequal(get(but,'Enable'),'on')
                moveThroughSignal('','','x-');
            end
        case 'r'
            but = analysisToolGroup.Children(end);
            if isequal(get(but,'Enable'),'on')
                findQRS('','');
            end
        case 'o'
            if isequal(event.Modifier,{'control'})
                selectFile('','');
            end

    end 
end






















