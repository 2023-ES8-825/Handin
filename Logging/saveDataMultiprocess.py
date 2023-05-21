import pandas as pd
import git



def saveToFile(samplingTime: int, fileUpdateTime: int, newFileTime: int, uploadToGit:bool,uploadToGitTime:int, q):
    lastSamplingTime = 0
    lastFileUpdateTime = 0
    lastNewFileTime = 0
    lastUploadToGitTime = 0
    dataTimeSeries = pd.DataFrame()
    if(uploadToGitTime>newFileTime):
        uploadToGitTime = lastNewFileTime-5
    
    while True:
        data = q.get()
        try:
            dataTime = data["TimeHP"].iloc[-1]
        except:
            dataTime = data["TimeHVAC"].iloc[-1]

        if (dataTime > lastSamplingTime + samplingTime-0.1):
            lastSamplingTime = dataTime
            dataTimeSeries = pd.concat([dataTimeSeries, data])
            dataTimeSeries= dataTimeSeries.round(2)

            #Make new file
            if (dataTime > lastNewFileTime + newFileTime):
                lastNewFileTime = dataTime
                dataTimeSeries.to_csv(
                f"LogFilesLive\Log{int(lastNewFileTime)}.csv", index=False)
                #Empty data time series
                del dataTimeSeries
                dataTimeSeries = pd.DataFrame()

                if(uploadToGit==True and dataTime>lastUploadToGitTime+uploadToGitTime):
                    lastUploadToGitTime=dataTime
                    pushToGit(int(lastNewFileTime))

            #Update current file
            elif (dataTime > lastFileUpdateTime + fileUpdateTime):
                lastFileUpdateTime = dataTime
                dataTimeSeries.to_csv(
                f"LogFilesLive\Log{int(lastNewFileTime)}.csv", mode='a', index=False, header=False)
                del dataTimeSeries
                dataTimeSeries = pd.DataFrame()

                if(uploadToGit==True and dataTime>lastUploadToGitTime+uploadToGitTime):
                    lastUploadToGitTime=dataTime
                    pushToGit(int(lastNewFileTime))

                        

def pushToGit(FileName):
    try:
        repo = git.Repo("C:/Users/Lab/Desktop/ES8-825/git/labRepo")
        origin = repo.remote("origin")  
        assert origin.exists()
        origin.fetch()

        repo.index.add(f"UDPInterface/LogFilesLive/Log{FileName}.csv")  
        repo.index.commit("Automatic Logfile upload")
        repo.git.push("--set-upstream",origin, repo.head.ref)
        print("Finished push to git \n")
    except Exception as e: 
        print(e)

