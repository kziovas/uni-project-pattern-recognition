Scripts completed%% Remove rows with zero values in odds
MatchClean=[];
MatchZeros=[];
for i = 1:size(Match,1)
    row=Match(i,:);%This syntax gets the  llabels and the a=values in a table
    for j = 12:23
        odds= Match{i,j}; %This syntax gets the values only in an array
          if odds==0 
              MatchZeros=[MatchZeros;row];
              break;
          elseif odds~=0 && j==23
              MatchClean=[MatchClean;row];
          end
    end
end



%% Turn non numerical fields(season and date) to numerical before converting to array
season=[];
monthNumber=[];
dayOfWeek=[];
%id=[];
for i = 1:size(MatchClean,1)
    splitSeason=strsplit(MatchClean{i,4}{1,1},'/');
    seasonFirst=str2double(splitSeason{1,1}(3:4));
    season=[season;seasonFirst];%This syntax gets the only the value from a cell data type in a table
    %id=[id;double(MatchClean{i,1})];
end
%MatchNum=table(id);

for i = 1:size(MatchClean,1)
    dateValue=datetime(MatchClean{i,6}{1,1});
    monthNumber=[monthNumber;month(dateValue)];
    dayOfWeek=[dayOfWeek;day(dateValue,'dayofweek')];
    %id=[id;double(MatchClean{i,1})];
end

%% Append columns to new table
MatchNum=[];
for i=2:3 
    MatchNum=[MatchNum MatchClean(:,i)];
end
MatchNum=[MatchNum table(season)];

for i=5
    MatchNum=[MatchNum MatchClean(:,i)];
end
MatchNum=[MatchNum table(monthNumber)];
MatchNum=[MatchNum table(dayOfWeek)];

for i=7:size(MatchClean,2)
    MatchNum=[MatchNum MatchClean(:,i)];
end

writetable(MatchNum,"cleanMatchTable.csv",'WriteVariableNames',0);
%MatchFinArray=table2array(MatchNum);
MatchFinArray = csvread("cleanMatchTable.csv");

%% Extract predictions for each company in a seperate array
B365TrainArray=double(MatchFinArray(1:22000,12:14));
B365TrainArrayT=B365TrainArray.';
BWTrainArray=double(MatchFinArray(1:22000,15:17));
BWTrainArrayT=BWTrainArray.';
IWTrainArray=double(MatchFinArray(1:22000,18:20));
IWTrainArrayT=IWTrainArray.';
LBTrainArray=double(MatchFinArray(1:22000,21:23));
LBTrainArrayT=LBTrainArray.';
%% Scale train data
B365TrainArray=scaleOdds(B365TrainArray);
B365TrainArrayT=B365TrainArray.';

BWTrainArray=scaleOdds(BWTrainArray);
BWTrainArrayT=BWTrainArray.';

IWTrainArray=scaleOdds(IWTrainArray);
IWTrainArrayT=IWTrainArray.';

LBTrainArray=scaleOdds(LBTrainArray);
LBTrainArrayT=LBTrainArray.';
%% Extract game results
ResultsArray=[];
for i=1:22000%size(MatchFinArray,1)
    homeGoals=MatchFinArray(i,10);
    awayGoals=MatchFinArray(i,11);
    result=homeGoals-awayGoals;
    if result>0
        resultVector=[1 0 0];
    elseif result<0
        resultVector=[0 0 1];
    elseif result==0
        resultVector=[0 1 0];
    end
     ResultsArray=[ResultsArray;resultVector];  
        
end
ResultsArray=double(ResultsArray);
ResultsArrayT=ResultsArray.';
%numResult is an one dimensional array which contains the number of
%the match result (1=Home,2=Draw,3=Away)
numResult=[];
for i=1:size(ResultsArray,1)
    pred= find(ResultsArray(i,:)==1);
    numResult=[numResult;pred];
end
%% Train the Linear NN on B365
[netB365_SingleOdds,matchingB365SL,AccuracyB365SL] = LinearNNOdds(B365TrainArrayT,ResultsArrayT,numResult);

%% Train the Linear NN on BW
[netBW_SingleOdds,matchingBWSL,AccuracyBWSL] = LinearNNOdds(BWTrainArrayT,ResultsArrayT,numResult);

%% Train the Linear NN on IW
[netIW_SingleOdds,matchingIWSL,AccuracyIWSL] = LinearNNOdds(IWTrainArrayT,ResultsArrayT,numResult);

%% Train the Linear NN on LB
[netLB_SingleOdds,matchingLBSL,AccuracyLBSL] = LinearNNOdds(LBTrainArrayT,ResultsArrayT,numResult);

%% Train the Multilevel NN on B365 based on Odds only
[netB365_MultiOdds,matchingB365ML,AccuracyB365ML] = MultiNNOdds(B365TrainArrayT,ResultsArrayT,numResult);

%% Train the Multilevel NN on BW
[netBW_MultiOdds,matchingBWML,AccuracyBWML] = MultiNNOdds(BWTrainArrayT,ResultsArrayT,numResult);

%% Train the Multilevel NN on IW
[netIW_MultiOdds,matchingIWML,AccuracyIWML] = MultiNNOdds(IWTrainArrayT,ResultsArrayT,numResult);
%% Train the Multilevel NN on LB
[netLB_MultiOdds,matchingLBML,AccuracyLBML] = MultiNNOdds(LBTrainArrayT,ResultsArrayT,numResult);

%% Functions definition

% Odds are scaled with the maximum od at each line
function scaledOdds = scaleOdds(oddsArray)

    mOdd= max(oddsArray, [],2);
    scaledOdds=oddsArray./mOdd;
end

% Train Single layer NN based on Odds only
function [net,matching,accuracy] = LinearNNOdds(oddsArrayT,resultsArrayT,numResult)

net= feedforwardnet(3);
net.numLayers = 1;
net.trainParam.goal= 0.1;
net.trainParam.epochs = 128;
net.trainParam.lr = 0.0001;
net.outputConnect=1;
net.layers{1}.transferFcn = 'tansig';
init(net);
net = train(net,oddsArrayT,resultsArrayT); 
%view(net);
perf = perform(net,oddsArrayT,resultsArrayT);
pred=net(oddsArrayT).';
mpred= max(pred, [],2);
pred=pred./mpred;
pred(pred<1)=0;
numpred=[];
for i=1:size(pred,1)
    predSingle= find(pred(i,:)==1);
    numpred=[numpred;predSingle];
end
matching=numResult==numpred;
accuracy=nnz(matching)/size(matching,1);
end

% Train Multi layer NN based on Odds only
function [net,matching,accuracy] = MultiNNOdds(oddsArrayT,resultsArrayT,numResult)

net= feedforwardnet([27 9]);
net.numLayers = 3;
net.trainFcn = 'trainbr';
net.trainParam.goal= 0.1;
net.trainParam.epochs = 128;
net.trainParam.lr = 0.0001;
%net.outputConnect=1;
net.layers{1}.transferFcn = 'tansig';
net.layers{2}.transferFcn = 'tansig';
net.layers{3}.transferFcn = 'purelin';
init(net);
net.trainParam.max_fail = 16;
net = train(net,oddsArrayT,resultsArrayT); 
%view(net);
perf = perform(net,oddsArrayT,resultsArrayT);
pred=net(oddsArrayT).';
mpred= max(pred, [],2);
pred=pred./mpred;
pred(pred<1)=0;
numpred=[];
for i=1:size(pred,1)
    predSingle= find(pred(i,:)==1);
    numpred=[numpred;predSingle];
end
matching=numResult==numpred;
accuracy=nnz(matching)/size(matching,1);
end