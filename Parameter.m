%%
clear
close all
clc

CAN2EthernetDelay = 0.000;
Ethernet2CANDelay = 0.005;
CycleSwitch = 0.06/1000;    % 0.06 ms
CyclePLC = 24/1000;    % 24 ms
CycleTx = 0.0/1000;    % 0.06 ms
CycleRx = 0.0/1000;    % 0.06 ms
Cycle_Controller = 0; %3e-3;

ReferenceDelay = 0.0;
band = 100000000;   % default bandwidth 100 MB/s
BER = 0;    % default bit error rate
SampleTime = 0.01;  % For router

%Streckenparameter
i = 0; %Steigung/Gefälle in Promille

% -----------------------
% Zugparameter allgemein
% -----------------------
nW_ges = 8; %Anzahl Wagen gesamt
nW_an = 4; %Anzahl Triebwagen
nM = 4; %verfügbare Motoren; nur abweichend von Anzahl Triebwagen, 
% wenn Ausfall einer E-Bremse simuliert werden soll
nW_frei = 4; %Anzahl Wagen ohne Antrieb

% -----------------------
% Wagenparameter allgemein
% -----------------------
mges = 58000; %Wagenmasse [kg] 
mA =  1500; %Masse einer Achse [kg] 
nA = 4; %Anzahl Achsen
Dr = 0.92; %Laufkreisdurchmesser [m] 
J = 1/2*mA*(Dr/2)^2; %Trägheit der Achse [kg m^2]

tol = 0.05; %Toleranz zu Null
um = 3.6; %Umrechnungsfaktor m/s in km/h
% Wagenkupplung
c = 5000000; %Federkonstante [N/m]
d = 800000; %Dämpfungskonstante [N*s/m]

% -----------------------
% Kraftschlussmodell
% -----------------------
sc = 0.008; muc = 0.4; mug = 0.1; %trocken
%sc = 0.02; muc = 0.12; mug = 0.05; % feucht ohne Sand
%sc =0.008; muc = 0.28; mug = 0.08; % feucht mit Sand 
n = 0.001;
co = 3*muc/sc;
s1 = 0:n:sc;
s2 = sc+0.0001:n:1;
mu1 = co*s1-1/3*co^2*s1.^2/muc+1/27*co^3*s1.^3/(muc^2);
Sp = 4; 
mu2 = muc-(muc-mug)*tanh(Sp*(s2-3*muc/co)).^2;
slip = [s1 s2];
mu = [mu1 mu2];
%plot(slip,mu);

% -----------------------
% Widerstandskräfte Konstanten
% -----------------------
rho = 1.08; %Massenträgheitsfaktor
g = 9.81; %Erdbeschleunigung [m/s^2]
cR = 1.5*10^-3; %Rollwiderstandkonstante
rhoL = 1.225; %Dichte von Luft [kg/m^3]
cwE = 0.35; %cw-Wert Endwagen 
cwM = 0.08; %cw-Wert Mittelwagen
cw = (cwE * 2 + cwM * (nW_ges-2))/nW_ges; %Mittelwert für cw-Wert 
A = 10; %Stirnfläche für Luftwiderstand [m^2]
c1 = 4.33; %Konstante für Widerstand Bremskühlung [N]
c2 = 3.16; %Konstante für Widerstand Bremskühlung [N]
v00 = 100/3.6; %Refferenzgeschwindigkeit 100 km/h [m/s]
Q = 10; %Luftstrom pro Wagen für Kühlung(Klima und Motor) [m^3/s]

% -----------------------
% Pneumatische Bremse nach Knorr-Schnellzugbremsen KE-GPR
% -----------------------
P_zmax = 3.8*10^5; %maximaler Bremszylinderdruck [Pa]
d_z = 8*0.0254; %Durchmesser Bremszylinder [m]
Fge =  1500; %Gegenkraft im Bremszylinder [N]
A_KZ = pi*d_z^2/4; %Kolbenfläche [m^2]
F_KZmax = A_KZ*P_zmax -Fge; %Maximale Kolbenkraft des Bremszylinders [N]
R_mW = 0.200; %Bremsradius Wellenbremsscheibe [m] 520 x 110 gültig für nicht angetriebene Achsen
R_mR = 0.289; %Bremsradius Radbremsscheiben [m] 740/425 gültig für angetriebene Achsen
nG = 0.9; %Gestängewirkungsgrad
iG = 182/158*2; %Übersetzung Bremsgestänge für Einzelzange
muBel1 = 0.42; %Wert für Belagreibwertkurve
muBel2 = 0.36; %Wert für Belagreibwertkurve
nBan = 2; %Anzahl Bremsscheiben pro angetriebener Achse
nBfrei = 3; %Anzahl Bremscheiben pro nicht angetriebener Achse
FBel_an = iG*nG*F_KZmax*nBan*R_mR/(Dr/2); %maximale Belagskraft pro angetriebener Achse
FBel_frei = iG*nG*F_KZmax*nBfrei*R_mW/(Dr/2); %maximale Belagskraft pro freier Achse

% -----------------------
% Dynamische Bremse
% -----------------------
Fmaxdyn = 300000; %maximale dynamische Bremskraft [N]
P_max = 8200000; %maximale Leistung der dynamische Bremse [W]
F_konst = 70892; %Kraftkonstatne im unteren Geschwindigkeitsberiech [N] 
r_reib = 600; %Konstante für Reibungsverluste [kg/s] für mittleren Geschwindigkeitsbereich

% -----------------------
% Magnetschienenbremse Knorr Bremse DD.GL. 120
% -----------------------
FA = 100000; %Anzugskraft [N|
k1 = 0.095; %Reibwertkonstante 
k2 = 9.26/3.6; %Geschwindigkeitskonstante [m/s] [bei Nässe: 13.89]
k3 = 4.63/3.6; %Geschwindigkeitskonstante [m/s] [bei Nässe: 5.56]
v_grenz = 60/3.6; %50 km/h Abschaltung Mg-Bremse und WB-Bremse [m/s]
n_Mg = 4; %Anzahl Magnetschinenbremsen pro nichtangetriebenem Wagen

% -----------------------
% Wirbelstrombremse
% -----------------------
FB_WB_max = 10000; %Maximale Bremskraft WB-Bremse [N]
v_opt = 75/3.6; %optimaler Betriebspunkt [m/s]
W_opt = 0.5;  %Parameter im optimalen Betriebspunkt
y_opt = sqrt(W_opt)/((1+sqrt(W_opt))^2+W_opt);
n_WB = 4; %Anzahl WB-Bremse pro nichtangetriebenem Wagen
WB = 1; %Ausrüstung mit WB[>0] oder Mg[0] Bremse

% -----------------------
% Gleitschutz
% -----------------------
a = 1;
b = 0.005;
ab = 5;

% -----------------------
% Sensors
% -----------------------
CycleTime_Sensor = 1/1000;
Size=8;
%% Entity Structures
load('Entity_Structures.mat') 