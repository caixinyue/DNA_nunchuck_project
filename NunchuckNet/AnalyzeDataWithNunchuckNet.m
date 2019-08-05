clear;clc;
%Note: NN stands for NunchuckNet

load('nunchucknet.mat');
net=nunchucknet;
fclose('all'); %closes opened files to prevent running into problems with rmdir

if exist('NNStacks')==0 %all image sequences (in tiff format) must be moved to a folder "NNStacks" in matlab directory
    disp('NNStacks folder not found: Aborting'); 
    return
end

[numStacks,folderNames]=splitStack(); %splits stacks and prepares images for NN analysis

disp('Analyzing:')

path=strcat(pwd,'/NNStacks/');
edges=[-180:5:180];

for i=1:numStacks%for each movie
    name=folderNames{i}; %Name of file with "Split" appended to it
    disp(strcat('>>> ',name(1:end-5),':'))
    
    stack_ds=imageDatastore(strcat(path,folderNames(i))); %creates imagedatastore fed to NN
    [preds,scores] = classify(net,stack_ds); %Gets predictions and scores
    [raw_nnba]=convertToDouble(preds); %converts from categorical to double

    %filter out images with low (2 std away) scores, after filtering out blank frames
    clear predsFiltered scoresFiltered
    [nnba,maxScores,framesFiltered]=filterPreds(raw_nnba,scores);
    
    %save files/results
    data.name{i}=name(1:end-5);
    data.nnba{i}=nnba;
    data.raw_nnba{i}=raw_nnba;
    data.binned{i}=histcounts(abs(nnba),[0:10:180]);
    data.score{i}=maxScores;
    data.allscore{i}=scores;
    
    writeNewStacks(name,stack_ds,raw_nnba,maxScores,framesFiltered);
   
    rmdir(strcat(pwd,'/NNStacks/',folderNames(i)),'s') %removes split folders
end
save('/Users/ambercai/Desktop/matlab/data_files/test.mat','data');

disp('Completed!')

fclose('all'); %closes all opened files

cd movie_analysis/NN_analysis/

%------------------Functions----------------------
function [num,out]=splitStack()
%This function splits the stack into individual images and prepares them to run though NN
%(changes resolution and type to true color)

stacks=dir('NNStacks/*.tif*'); %tif stacks in the folder
numStacks=length(stacks) %number of stacks in the folder
folders=strings(1,numStacks); %contain folder names for analysis function

for k=1:numStacks %will split up every stack 
    stackName=stacks(k).name; %gets the file name of the stack
    
    stackPath = strcat(pwd,'/NNStacks/',stackName); %path of stack file

    endin=strfind(stackName,'.');
    folderName=strcat(stackName(1:endin-1),'Split'); %foldername based on stack name
    folders(k)=folderName;
    
    if exist(strcat('NNStacks/', folderName))==7 %Skips if split folder is present
        disp(strcat(folderName, ": Split Folder already present"))
        continue
    end
    
    mkdir ('NNStacks', folderName); %folder wehere split is going to be saved to
    folderPath=strcat(pwd,'/NNStacks/',folderName,'/'); %path to save folder
    
    info = imfinfo(stackPath); %info about stack 
    numFrames= numel(info); %number of frames in the stack

    for i = 1:numFrames %saves each modified frame as individual file
        if i<10 %name for individual frame files-needed for image dataStores
            name=strcat('000',num2str(i));
        elseif i<100 && i>9
            name=strcat('00',num2str(i));
        elseif i<1000 && i>99
            name=strcat('0',num2str(i));
        else
            name=num2str(i);
        end

        A = imread(stackPath, i, 'Info', info); %reads specific frame
        A(201:227,201:227)=0; %changes resolution from 200x200 to 277x277
        A = cat(3, A,A,A); %changes from 8bit to truecolor
        fileName=strcat(folderPath,name,'.tif'); %filename is frame number
        imwrite(A,fileName); %writes frame
    end
end
num=numStacks;
out=folders;
end

function [raw_nnba]=convertToDouble(preds)
    %This next portion will convert the predictions from a categorical
    %array to a double array
    
    preds=string(preds);
    predsSize=numel(preds);
    raw_nnba=zeros(1,predsSize);

    for j=1:predsSize
        raw_nnba(j)=eval(preds(j));
        raw_nnba(j)=str2num(strcat(num2str(raw_nnba(j)),'.5'));
    end
end


function [nnba,maxScores,framesFiltered]=filterPreds(raw_nnba,scores)
    clear maxScores
    clear framesFiltered
    
    predsSize=numel(raw_nnba);
    excluded=0; %count for excluded images start
    maxScores=zeros(1,predsSize); %initializing array that will contain highscores
    nnba=zeros(1,predsSize);
    
    for frame=1:predsSize %for each frame
        highScore=max(scores(frame,:)); %highest score for this frame
        
        if isnan(raw_nnba(frame)) || highScore<0.07 %is this frame's angle is NaN, or if score is super low (probably empty frame)
            maxScores(frame)=NaN;%set score to NaN
        else
            maxScores(frame)=highScore;
        end
    end
    
    
    for frame=1:predsSize %filters out low score frames
        if maxScores(frame)>(nanmean(maxScores)-2*nanstd(maxScores))
            scoresFiltered(frame)=maxScores(frame); %saves values for frames with high enough scores
            nnba(frame)=raw_nnba(frame);
        else%sets excluded frames to NaN
            excluded=excluded+1;
            framesFiltered(excluded)=frame;
            scoresFiltered(frame)=NaN;
            nnba(frame)=NaN;
       	end
    end
    disp(strcat('meanScore:',num2str(nanmean(maxScores)),' stdScore:',num2str(nanstd(maxScores)),' threshold:',num2str(nanmean(maxScores)-1.5*nanstd(maxScores))))
    disp(strcat(num2str(excluded),' frames excluded due to low scores'))
end


function writeNewStacks(name,stack_ds,raw_nnba,maxScores,framesFiltered)

    numFrames=numel(stack_ds.Files); %number of frames for the movie
 
    
    for k=1:numFrames %loops through frames of stack
        savePath=strcat(pwd,'/NNStacks/',name(1:end-5),'_NNAnglesInserted.tif');
        img=readimage(stack_ds,k); %reads image from split folder
        
        text=strcat(num2str(raw_nnba(k)),' | ',num2str(round(maxScores(k),2))); %text that will be written
        if ismember(k,framesFiltered) %adds * if ignored
            text=strcat(text,'*');
        end
        
        img=insertText(img,[5,5],text); %inserts text
        
        img=img(1:200,1:200); %changes it back to 200x200 and grey scale
        
        if k~=1 %writes stack by appending to the stack each consecutive image
            imwrite(img,savePath,'WriteMode','append'); 
        else
            imwrite(img,savePath);
        end
    end

end