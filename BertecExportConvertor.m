clear
expath='oldExport\';
f1=figure('MenuBar','none','Name','Bertec Export Format Conversion','NumberTitle','off');
str='This program reads a new Bertec export file and converts it to the old export format.';
annotation('textbox',[0.05,0.6,0.3,0.3],'String',str,'FitBoxToText','on');
str='1. Select a valid export file';
annotation('textbox',[0.07,0.53,0.3,0.3],'String',str,'FitBoxToText','on','EdgeColor','none');
str='2. The files will be saved to a subfolder named oldExport under the same folder';
annotation('textbox',[0.07,0.49,0.3,0.3],'String',str,'FitBoxToText','on','EdgeColor','none');
str='containing the original file';
annotation('textbox',[0.092,0.45,0.3,0.3],'String',str,'FitBoxToText','on','EdgeColor','none');
[infilename,pathname] = uigetfile({'*.csv';'*.txt'},'Select BBA Export file');
datafile=strcat(pathname,infilename);
str='Please Wait...';
pw=annotation('textbox',[0.4,0.3,0.3,0.3],'String',str,'FitBoxToText','on','EdgeColor','none');
pause(0.2);
tmp=strsplit(infilename,'-');
basefile=strcat(tmp{1},'-',tmp{2},'-');
basepath=strcat(pathname,expath);
%
fid = fopen(datafile);
nInfo=0;
nSettings=0;
nResults=0;
nForce=0;
i=0;
while ~feof(fid) % Trying to find the beginning of the data by parsing the header
    i=i+1;
    lineIN = fgetl(fid);
    switch lineIN
        case 'INFO' % Identify the beginning of INFO section 
            nInfo=i;
        case 'SETTINGS' % Identify the beginning of SETTINGS section 
            nSettings=i;
        case 'RESULTS' % Identify the beginning of RESULTS section 
            nResults=i;
        case 'FORCE'   % Identify the beginning of FORCE section 
            nForce=i;
            break
    end
end
if nInfo==0 % Verify that the file is a Bertec export file and if not, generate an error
    clf(f1);
    str='ERROR - The selected file is not a Bertec export file';
    annotation('textbox',[0.1,0.6,0.3,0.3],'String',str,'FitBoxToText','on','EdgeColor','r');   
    EXIT
end
if nSettings==0 %   If the SETTINGS section does not exist, skip to RESULTS
    nNext=nResults;
else
    nNext=nSettings;
end
frewind(fid); % Go back to the top of teh file
j=0;
Infocsv=cell(2,8);
Infocsv{1,7}='Test Options';
for i=1:nNext-2 % Read the INFO section
    if i<nInfo+1
        lineIN = fgetl(fid);
    else
        lineIN = fgetl(fid);
        j=j+1;
        tempstr=strsplit(lineIN,',');
        Info{j,1}=replace(tempstr(1),'_',' ');
        Info(j,2)=tempstr(2);
        if length(tempstr)> 2
            for k=3:length(tempstr)
                Info(j,2)=strcat(Info(j,2),',',tempstr(k));
            end
        end
        switch char(Info{j,1})
        case 'Patient Name' % 
            Infocsv{1,1}=char(Info{j,1});
            Infocsv{2,1}=char(Info{j,2});
        case 'Patient Age' % 
            Infocsv{1,2}=char(Info{j,1});
            Infocsv{2,2}=char(Info{j,2});
        case 'DOB' % 
            Infocsv{1,3}=char(Info{j,1});
            Infocsv{2,3}=char(Info{j,2});            
        case 'Patient Gender' % 
            Infocsv{1,4}='Gender';
            Infocsv{2,4}=char(Info{j,2});
        case 'Operator' % 
            Infocsv{1,5}=char(Info{j,1});
            Infocsv{2,5}=char(Info{j,2});
        case 'Test Name' % 
            Infocsv{1,6}=char(Info{j,1});
            Infocsv{2,6}=char(Info{j,2});     
            Testname=Info{j,2};
            nTest=j;            
        case 'Test Option' % 
            Infocsv{1,7}=char(Info{j,1});
            Infocsv{2,7}=char(Info{j,2});
        case 'Session Note' % 
            Infocsv{1,8}='Test Comments';
            Infocsv{2,8}=char(Info{j,2});              
        end
       if strcmp(char(Info{j,1}),'Height') % Get Height
            heightstr=char(Info{j,2});
            idx1=strfind(heightstr,39);
            if isempty(idx1)
                height= str2double(heightstr);
            else
                hft= str2double(heightstr(1:idx1-1));
                idx2=strfind(heightstr,'"');
                hin= str2double(heightstr(idx1+1:idx2-1));
                height=hft*0.3+hin*0.0254;
            end       
       end  
    end
end
j=0;
for i=nNext-1:nResults-2 % Read the SETTINGS or skip if there is none
    if i<nNext+1
        lineIN = fgetl(fid);
    else
        lineIN = fgetl(fid);
        j=j+1;
        tempstr=strsplit(lineIN,',');
        Settings(j,1)=tempstr(1);
        for k=2:length(tempstr)
            Settings(j,k)=tempstr(k);
        end
    end   
end
j=0;
for i=nResults-1:nForce-2 % Read the RESULTS 
    if i<nResults+1
        lineIN = fgetl(fid);
    else
        lineIN = fgetl(fid);
        j=j+1;
        tempstr=strsplit(lineIN,',','CollapseDelimiters',0);
        if i > nResults +1 && ~strcmp(tempstr(1),'Fall') % Take care of the Fall
            Results(j,1)=tempstr(1);
            for k=2:length(tempstr)
                Results{j,k}=str2num(char(tempstr(k)));
            end
        else
            for k=2:length(tempstr)
                if isempty(char(tempstr(k)))
                    tempstr(k)=tempstr(k-1);
                end
            end            
            Results(j,:)=tempstr;
        end
    end   
end
if strcmp(Results(2,1),'Trial')
    TrialFlag=1;
else
    TrialFlag=0;
end
TForce=readtable(datafile,'Delimiter','comma','HeaderLines',nForce);  % Read the force data into a table
jj=0;
for i=2:size(Results,2)
    Cond=Results{1,i};
    if TrialFlag==1
        Trial=Results{2,i};
        if ~isnumeric(Trial)
            Trial=str2num(Results{2,i});
        end
        Tcol2=table2array(TForce(:,2));
        if ~isnumeric(TForce{1,1})
            T=TForce(strcmp(TForce{:,1},Cond) & Tcol2(:,1)==Trial,:);
        else
            Tcol1=table2array(TForce(:,1));
            T=TForce(Tcol1(:,1)==str2num(Cond) & Tcol2(:,1)==Trial,:);
        end
    elseif strcmp(Results{1,1},'Target') || strcmp(Results{1,1},'Condition')
        T=TForce(strcmp(TForce{:,1},Cond),:);
    else
        Trial=Results{1,i};
        if ~isnumeric(Trial)   
            Trial=str2num(Results{1,i});
        end
        Tcol1=table2array(TForce(:,1));
        T=TForce(Tcol1(:,1)==Trial,:);
    end
    if size(T,1)~=0
        jj=jj+1;
        tmpcel={'Height mm',height*1000};
        Resultscsv=[Results(:,[1,i]);tmpcel]';
        if jj==1
            infofile=strcat(pathname,expath,basefile,'1-',Testname,'-Info.csv');
            [~,~]=mkdir(pathname,expath);
            fid2=fopen(infofile,'w');
            for j=1:size(Infocsv,1)
                for k=1:size(Infocsv,2)
                    fprintf(fid2,'%s',Infocsv{j,k});
                    if k==size(Infocsv,2)
                        fprintf(fid2,'\n');
                    else
                        fprintf(fid2,'%s',',');
                    end
                end
            end
            fclose(fid2);
        end
        resultsfile=strcat(pathname,expath,basefile,num2str(jj),'-',Testname,'-Results.csv');
        fid2=fopen(resultsfile,'w');
        for j=1:size(Resultscsv,1)
            for k=1:size(Resultscsv,2)
                if isnumeric(Resultscsv{j,k})
                    fprintf(fid2,'%f',Resultscsv{j,k});
                else                   
                    fprintf(fid2,'%s',Resultscsv{j,k});
                end
                if k==size(Resultscsv,2)
                    fprintf(fid2,'\n');
                else
                    fprintf(fid2,'%s',',');
                end
            end
        end
        fclose(fid2);
        forcefile=strcat(pathname,expath,basefile,num2str(jj),'-',Testname,'-Force.csv');
        if strcmp(Testname,'Limits of Stability')
            apfile=strcat(pathname,expath,basefile,num2str(jj),'-',Testname,'-COGangleAP.csv');
            mlfile=strcat(pathname,expath,basefile,num2str(jj),'-',Testname,'-COGangleML.csv');
            Tap=T(:,1);
            Tml=T(:,2);
            Tf=T(:,3:end);
            writetable(Tap,apfile);
            writetable(Tml,mlfile);
            writetable(Tf,forcefile);
        else
            writetable(T,forcefile);
        end
    end
end
delete(pw);
str='Finished!  The files are saved in:';
annotation('textbox',[0.3,0.3,0.3,0.3],'String',str,'FitBoxToText','on','EdgeColor','none');
annotation('textbox',[0.1,0.2,0.3,0.3],'String',strcat(pathname,expath),'FitBoxToText','on','EdgeColor','none');

