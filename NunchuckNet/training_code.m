net=alexnet;
fakeNun_ds=imageDatastore('FakeNunchuckImages','IncludeSubfolders',true,'LabelSource','foldernames');
[testImgs,trainImgs,validationImgs] = splitEachLabel(fakeNun_ds,0.29,0.7,'Randomize');
numClasses = numel(categories(fakeNun_ds.Labels));
layers=net.Layers;
layers(end-2)=fullyConnectedLayer(numClasses);
layers(end) = classificationLayer;

options = trainingOptions('sgdm','InitialLearnRate', 0.01,'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',1,'LearnRateDropFactor',0.1,'Plots','training-progress','MaxEpochs',30,...
    'MiniBatchSize',360,'Shuffle','every-epoch','ValidationData',validationImgs,'ValidationFrequency',140,...
    'ValidationPatience',4,'ExecutionEnvironment','gpu');

[nunhcucknet,info] = trainNetwork(trainImgs, layers, options);