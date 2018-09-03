import sys
sys.path.insert(1,'/Library/Python/2.7/site-packages')
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import math
from scipy import optimize as op
import corner as triangle
from collections import Counter

def squarediff(x, j):
    thissum=0.
    for i in range(Neps+1):
        indx=int(x*i)
        if (indx > Neps):
            diff=evidences[0][i]-1.0
        else:
            diff=(evidences[0][i]-evidences[j][indx])
        thissum+=diff*diff
    #if (x < 1.0):
    #    for i in range(Neps+1):
    #        indx=int(x*i)
    #        diff=(evidences[0][i]-evidences[j][indx])
    #        thissum+=diff*diff
    #else:
    #    for i in range(Neps+1):
    #        indx=int(1.0*i/x)
    #        diff=(evidences[j][i]-evidences[0][indx])
    #        thissum+=diff*diff
        
    return(thissum)

def squarelogdiff(x, j):
    thissum=0.
    for i in range(Neps+1):
        indx=int(x*i)
        if (indx < len(evidences[j])):
            if ((evidences[0][i]>0.) and (evidences[j][indx] > 0.)):
                diff=(np.log(evidences[0][i])-np.log(evidences[j][indx]))
            else:
                diff=0.
        else:
            if (evidences[0][i]>0.):
                diff=np.log(evidences[0][i])
            else:
                diff=0.
        thissum+=diff*diff
    #print thissum
    return(thissum)

def altsquarelogdiff(x, j):
    thissum=0.
    for i in range(1,Neps+1):
        indx=int(x*i)
        if (indx > Neps):
            diff=logevidences[0][i]
        else:
	    if (indx == 0):
                indx=1
	    diff=(logevidences[0][i]-logevidences[j][indx])
        thissum+=diff*diff
    return(thissum)

if ((len(sys.argv) != 2)):
    print "Please indicate on the command line which dataset you wish to analyse:"
    print "    1: CEDSS ABC5 data set" 
    exit(0)

#Select data set. 1 = 10000 point dataset, 2 = June full data set, 3 = August full data set, 4 = December full data set
whichdataset=int(sys.argv[1])

#df=pd.read_csv('data/cedss-abc-results.csv', sep=',',header=0)
if whichdataset==1:
    df=pd.read_csv('data/cedss-abc5-results_split0_withLogCols.csv', sep=',',header=0)
    dfsecond=pd.read_csv('data/cedss-abc5-results_split1_withLogCols.csv', sep=',',header=0)
else:
    print "Unrecognized choice of data set, exiting!"
    sys.exit()

datasetlabels=['SplitSampleDataSet']

#headers=['appliance.elect.error','appliance.gas.error','space.heating.elect.error','space.heating.gas.error','space.heating.oil.error','water.heating.elect.error','water.heating.gas.error','water.heating.oil.error']
#calibvals=[328369,50839,159740,3307148,18198,73544,833652,3701]
#headers=['appliance.elect.error','appliance.gas.error','space.heating.elect.error','space.heating.gas.error','space.heating.oil.error','water.heating.gas.error','water.heating.oil.error']
headers=['abs.total.error','log.rel.space.error','log.rel.appliances.error','log.rel.appliances.ratio.error']
#params=['bioboost','biospherism1']
#params=['egoism1','hedonism1','habitadjust','visits']
#params=['egoism1','hedonism1','habitadjust','bioboost','frame1']
#params=['credit','planning1','planning2','visits']
params=['credit','visits','frame1','hedonism1','maxlinks','bioboost']
#calibvals=[328369,50839,159740,3307148,18198,833652,3701]
calibvals=[0,0,0,0]
initscales=1.0*np.ones_like(calibvals)
optscales=1.0*np.ones_like(calibvals)
logoptscales=1.0*np.ones_like(calibvals)
for i in range(len(headers)):
    initscales[i]=1.0*(max(np.fabs(df[headers[i]])))

#c=Counter(np.array(df['visits']))
#print c.items()
#sys.exit()
plotfigs=1
compscales=1
#compscales=0
maketriangleplots=1
refeps=0.05

for j in range(len(calibvals)):
    print min(df[headers[j]])
    print min(dfsecond[headers[j]])
    print max(df[headers[j]])
    print max(dfsecond[headers[j]])
    print min(np.fabs(df[headers[j]]))/max(np.fabs(df[headers[j]]))
    print min(np.fabs(dfsecond[headers[j]]))/max(np.fabs(dfsecond[headers[j]]))
sys.exit()

Neps=100
maxeps=1.0
epvals=[1.0*(maxeps/Neps)*i for i in range(Neps+1)]
evidences=np.zeros(len(calibvals)*(Neps+1))
evidences=evidences.reshape((len(calibvals),Neps+1))
evratio=np.zeros(len(calibvals)*(Neps+1))
evratio=evratio.reshape((len(calibvals),Neps+1))
logevidences=np.zeros(len(calibvals)*(Neps+1))
logevidences=logevidences.reshape((len(calibvals),Neps+1))
moments=1.0*np.zeros_like(calibvals)
logmoments=1.0*np.zeros_like(calibvals)
for i in range(Neps+1):
    for j in range(len(calibvals)):
	thislst=dfsecond[headers[j]]
	print thislst
	print np.fabs(thislst/initscales[j])
        indx=np.where(np.fabs(thislst/initscales[j]) < epvals[i])
	print indx
	sys.exit()
        evidences[j][i]=1.0*sum(1 for val in 1.0*np.array(dfsecond[headers[j]][thislst]) if np.fabs(val/initscales[j]) < epvals[i])/(1.0*len(df[headers[j]]))
        if (i > 0):
	    evratio[j][i]=1.0*sum(1 for val in 1.0*np.array(dfsecond[headers[j]][thislst]) if np.fabs(val/initscales[j]) < epvals[i])/(1.0*epvals[i]*len(df[headers[j]]))
        else:
	    evratio[j][i]=0.0
	moments[j]=moments[j]+evidences[j][i]*epvals[i]
        #print evidences[j][i], moments[j]
        if (evidences[j][i] > 0.):
            logevidences[j][i]=np.log(evidences[j][i])
            logmoments[j]=logmoments[j]+np.log(evidences[j][i])*epvals[i]
sys.exit()

if (compscales):
    for j in range(len(calibvals)):
        res = op.minimize_scalar(squarediff, args=j)
        optscales[j]=res.x
        #logres = op.minimize_scalar(squarelogdiff, args=j,bounds=(0,10))
        logres = op.minimize_scalar(altsquarelogdiff, args=j,bounds=(0,10),method='bounded')
        logoptscales[j]=logres.x
        #optscales[j]=math.sqrt(moments[0]/moments[j])
        #logoptscales[j]=math.sqrt(logmoments[0]/logmoments[j])
else:
    if whichdataset==1:
        #For 10000 point data set
        optscales=[1.00000003,  0.49701209,  2.45734723,  1.92618766,  0.59742363,  1.79508192,  1.84390911]
        logoptscales=[1.01020297,  0.66694802,  9.75487738,  5.01826763,  0.75263322,  7.60846159,  2.36068513]
    elif whichdataset==2:
	#For June full data set
	optscales=[ 1.00000003,  0.46269778,  2.90032411,  2.26928082,  0.71804864,  1.98733833, 2.07978023]
	logoptscales=[ 1.01066709,  0.67061109,  9.67834354,  8.60356862,  0.92874148,  6.2929358,  3.5410582 ] 
    elif whichdataset==3:
	#For revised full data set
    	optscales=[ 1.00000003,  0.50668116,  2.62610518,  2.11920335,  0.73240833,  1.82764737, 2.30623463]
    	logoptscales=[ 1.01171154,  0.55702385,  7.71779204,  6.02313515,  0.86259533,  9.75234439, 3.53300704]
    elif whichdataset==4:
	#For December data set
    	optscales=[ 1.00000002, 0.57320673, 2.70469368, 2.161647, 0.72252623, 1.96430477, 2.30155122]
	logoptscales=[ 1.00785582, 0.71541732, 8.51256119, 5.0189048, 0.85955376, 8.8079923, 3.52347445]
    elif whichdataset==5:
	#For December log data set
	optscales=[ 1.00000003,  1.13018525,  0.66437255,  0.79839934]
	logoptscales=[ 1.00746564,  1.32258811,  0.39816676,  0.46617584]
    elif whichdataset==6:
	#For null log data set
	optscales=[ 1.00000003,  1.78810892,  1.71128588,  1.76477248]
	logoptscales=[ 1.00409682,  2.00969392,  1.49386182,  2.01017916]
    elif whichdataset==7:
	#For December first 64154 log data set
	optscales=[ 1.00000003,  1.12973244,  0.68839366,  0.78520967]
	logoptscales=[ 1.00792126,  1.36414031,  0.4162594,   0.42716665]
    elif whichdataset==8:
	#For December 19 not null first 64154 log data set
	optscales=[ 1.00000003,  1.13215119,  0.63541679,  0.76136669]
	logoptscales=[ 1.00761079,  1.33478808,  0.36804362,  0.39834098]
    elif whichdataset==20:
        optscales=[ 1.00000002,  1.06066118,  0.91362183,  0.40285427]
        logoptscales=[ 4.97749515,  6.31443827,  6.64323407,  8.91821879]
    else:
	print "Unrecognized choice of data set, exiting!"
	sys.exit()

print optscales
print logoptscales

lc=['b','g','r','c','m','y','k','b']
ls=['-','-','-','-','-','-','--','--']
#target=1
#plt.plot(np.array(epvals),np.log(evidences[0]),linestyle='-',color='k',label='reference')
#for j in range(8):
#    factor=0.25*(j+1)
#    thisscale=logoptscales[target]*factor
#    print factor,thisscale,altsquarelogdiff(thisscale,target)
#    plt.plot(np.array(epvals)/thisscale,logevidences[target],linestyle=ls[j],color=lc[j],label='scale = %f'%factor)
#plt.xlim([0,1])
#legend=plt.legend(loc='lower right',shadow=True)
#plt.show()
#plt.close()
#sys.exit()

if (plotfigs):
    for j in range(len(calibvals)):
        #plt.plot(np.array(epvals),(evratio[j]),linestyle=ls[j],color=lc[j],label=headers[j])
        plt.plot(np.array(epvals),(evratio[j]),linestyle=ls[j],color=lc[j],label='Metric %i'%(j+1))
    #legend=plt.legend(loc='lower right',shadow=True)
    outdata=np.array(np.reshape(epvals,(Neps+1,1)))
    for j in range(len(calibvals)):
	np.append(outdata,np.reshape(evratio[j],(Neps+1,1)),axis=1)
	print evratio[j]
    np.savetxt("%s_EvidenceData.txt"%(datasetlabels[whichdataset-1]),outdata)
    plt.xlabel(r'$\epsilon_i$')
    plt.ylabel(r'${\cal Z}$')
    legend=plt.legend(loc='lower right',shadow=True)
    plt.xlim([0,1])
    if whichdataset==1:
        plt.savefig('EvidenceVEps_RelativeToRandom_SmallCalibrationSet.png')
    elif whichdataset==2:
        plt.savefig('EvidenceVEps_RelativeToRandom_FullCalibrationSet_WithoutDodgyRow.png')
    elif whichdataset==3:
        plt.savefig('EvidenceVEps_RelativeToRandom_RevisedFullCalibrationSet.png')
    elif whichdataset==4:
        plt.savefig('EvidenceVEps_RelativeToRandom_DecemberCalibrationSet.png')
    elif whichdataset==5:
        plt.savefig('EvidenceVEps_RelativeToRandom_DecemberCalibrationSet_Log.png')
    elif whichdataset==6:
        plt.savefig('EvidenceVEps_RelativeToRandom_NullSet_Log.png')
    elif whichdataset==7:
        plt.savefig('EvidenceVEps_RelativeToRandom_DecemberCalibrationSet_First64154_Log.png')
    elif whichdataset==8:
        plt.savefig('EvidenceVEps_RelativeToRandom_December19NotNullSet_First64154_Log.png')
    elif whichdataset==9:
        plt.savefig('EvidenceVEps_RelativeToRandom_BioboostNullSet_Log.png')
    elif whichdataset==10:
        plt.savefig('EvidenceVEps_RelativeToRandom_CreditNullSet_Log.png')
    elif whichdataset==11:
        plt.savefig('EvidenceVEps_RelativeToRandom_HabitNullSet_Log.png')
    elif whichdataset==12:
        plt.savefig('EvidenceVEps_RelativeToRandom_MaxLinksNullSet_Log.png')
    elif whichdataset==13:
        plt.savefig('EvidenceVEps_RelativeToRandom_PlanningNullSet_Log.png')
    elif whichdataset==14:
        plt.savefig('EvidenceVEps_RelativeToRandom_BiospherismNullSet_Log.png')
    elif whichdataset==15:
        plt.savefig('EvidenceVEps_RelativeToRandom_EgoismNullSet_Log.png')
    elif whichdataset==16:
        plt.savefig('EvidenceVEps_RelativeToRandom_FrameNullSet_Log.png')
    elif whichdataset==17:
        plt.savefig('EvidenceVEps_RelativeToRandom_HedonismNullSet_Log.png')
    elif whichdataset==18:
        plt.savefig('EvidenceVEps_RelativeToRandom_AllNullSet_Log.png')
    elif whichdataset==19:
        plt.savefig('EvidenceVEps_RelativeToRandom_December19NotNullSet_First104960_Log.png')
    elif whichdataset==20:
        plt.savefig('EvidenceVEps_RelativeToRandom_SplitDataSet_Split0_Log.png')
    elif whichdataset==21:
        plt.savefig('EvidenceVEps_RelativeToRandom_SplitDataSet_Split1_Log.png')
    else:
	print "Unrecognized choice of data set, exiting!"
	sys.exit()
    plt.show()
    plt.close()
    #sys.exit()

    for j in range(len(calibvals)):
        plt.plot(np.array(epvals)/optscales[j],(evidences[j]),linestyle=ls[j],color=lc[j],label=headers[j])
    plt.xlim([0,1])
    legend=plt.legend(loc='lower right',shadow=True)
    if whichdataset==1:
        plt.savefig('EvidenceVEps_RescaledToAppElec_SmallCalibrationSet.png')
    elif whichdataset==2:
        plt.savefig('EvidenceVEps_RescaledToAppElec_FullCalibrationSet_WithoutDodgyRow.png')
    elif whichdataset==3:
        plt.savefig('EvidenceVEps_RescaledToAppElec_RevisedFullCalibrationSet.png')
    elif whichdataset==4:
        plt.savefig('EvidenceVEps_RescaledToAppElec_DecemberCalibrationSet.png')
    elif whichdataset==5:
        plt.savefig('EvidenceVEps_RescaledToAppElec_DecemberCalibrationSet_Log.png')
    elif whichdataset==6:
        plt.savefig('EvidenceVEps_RescaledToAppElec_NullSet_Log.png')
    elif whichdataset==7:
        plt.savefig('EvidenceVEps_RescaledToAppElec_DecemberCalibrationSet_First64154_Log.png')
    elif whichdataset==8:
        plt.savefig('EvidenceVEps_RescaledToAppElec_December19NotNullSet_First64154_Log.png')
    elif whichdataset==9:
        plt.savefig('EvidenceVEps_RescaledToAppElec_BioboostNullSet_Log.png')
    elif whichdataset==10:
        plt.savefig('EvidenceVEps_RescaledToAppElec_CreditNullSet_Log.png')
    elif whichdataset==11:
        plt.savefig('EvidenceVEps_RescaledToAppElec_HabitNullSet_Log.png')
    elif whichdataset==12:
        plt.savefig('EvidenceVEps_RescaledToAppElec_MaxLinksNullSet_Log.png')
    elif whichdataset==13:
        plt.savefig('EvidenceVEps_RescaledToAppElec_PlanningNullSet_Log.png')
    elif whichdataset==14:
        plt.savefig('EvidenceVEps_RescaledToAppElec_BiospherismNullSet_Log.png')
    elif whichdataset==15:
        plt.savefig('EvidenceVEps_RescaledToAppElec_EgoismNullSet_Log.png')
    elif whichdataset==16:
        plt.savefig('EvidenceVEps_RescaledToAppElec_FrameNullSet_Log.png')
    elif whichdataset==17:
        plt.savefig('EvidenceVEps_RescaledToAppElec_HedonismNullSet_Log.png')
    elif whichdataset==18:
        plt.savefig('EvidenceVEps_RescaledToAppElec_AllNullSet_Log.png')
    elif whichdataset==19:
        plt.savefig('EvidenceVEps_RescaledToAppElec_December19NotNullSet_First104960_Log.png')
    elif whichdataset==20:
        plt.savefig('EvidenceVEps_RescaledToAppElec_SplitDataSet_Split0_Log.png')
    elif whichdataset==21:
        plt.savefig('EvidenceVEps_RescaledToAppElec_SplitDataSet_Split1_Log.png')
    else:
	print "Unrecognized choice of data set, exiting!"
	sys.exit()
    plt.show()
    plt.close()

    for j in range(len(calibvals)):
        plt.plot(np.array(epvals)/logoptscales[j],np.log(evidences[j]),linestyle=ls[j],color=lc[j],label=headers[j])
    plt.xlim([0,1])
    legend=plt.legend(loc='lower right',shadow=True)
    if whichdataset==1:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_SmallCalibrationSet.png')
    elif whichdataset==2:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_FullCalibrationSet_WithoutDodgyRow.png')
    elif whichdataset==3:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_RevisedFullCalibrationSet.png')
    elif whichdataset==4:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_DecemberCalibrationSet.png')
    elif whichdataset==5:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_DecemberCalibrationSet_Log.png')
    elif whichdataset==6:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_NullSet_Log.png')
    elif whichdataset==7:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_DecemberCalibrationSet_First64154_Log.png')
    elif whichdataset==8:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_December19NotNullSet_First64154_Log.png')
    elif whichdataset==9:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_BioboostNullSet_Log.png')
    elif whichdataset==10:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_CreditNullSet_Log.png')
    elif whichdataset==11:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_HabitNullSet_Log.png')
    elif whichdataset==12:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_MaxLinksNullSet_Log.png')
    elif whichdataset==13:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_PlanningNullSet_Log.png')
    elif whichdataset==14:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_BiospherismNullSet_Log.png')
    elif whichdataset==15:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_EgoismNullSet_Log.png')
    elif whichdataset==16:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_FrameNullSet_Log.png')
    elif whichdataset==17:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_HedonismNullSet_Log.png')
    elif whichdataset==18:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_AllNullSet_Log.png')
    elif whichdataset==19:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_December19NotNullSet_First104960_Log.png')
    elif whichdataset==20:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_SplitDataSet_Split0_Log.png')
    elif whichdataset==21:
        plt.savefig('EvidenceVEps_LogRescaledToAppElec_SplitDataSet_Split1_Log.png')
    else:
	print "Unrecognized choice of data set, exiting!"
	sys.exit()
    plt.show()
    plt.close()

if maketriangleplots:
    for j in range(len(calibvals)):
        #postsamples=df[k for k in len(df[headers[j]]) if np.fabs(df[headers[j]][k]-calibvals[j]) < refeps*initscales[j]*logoptscales[j] ]
    	postsamples=df[np.fabs(df[headers[j]]) < refeps*initscales[j]*logoptscales[j] ]
    	#print refeps*initscales[j]*logoptscales[j]
    	#print len(postsamples[headers[j]])
    	#print np.array(postsamples[params])[:,0:len(params)]
    	plotsamps=np.array(postsamples[params])[:,0:len(params)]
    	#print len(plotsamps[:,0])
    	if len(plotsamps[:,0]) > len(params):
    	    fig=triangle.corner(plotsamps,labels=params)
    	    fig.savefig("Triangleplot_%s_%s.png"%(datasetlabels[whichdataset-1],headers[j]),dpi=150)
    	    plt.show()
    	    plt.close()
    	else:
    	    print "Number of valid samples for metric ",j+1," is too small to make a plot, skipping....."

for j in range(len(calibvals)):
    postsamples=df[np.fabs(df[headers[j]]) < refeps*initscales[j]*logoptscales[j] ]
    altev=len(df[np.fabs(df[headers[j]]) < refeps*initscales[j]])
    plotsamps=np.array(postsamples[params])[:,0:len(params)]
    print j,len(plotsamps[:,0]),(1.0*len(plotsamps[:,0]))/(1.0*len(df[headers[j]])*refeps*logoptscales[j]),(1.0*altev)/(1.0*len(df[headers[j]])*refeps)
    for k in range(len(params)):
        plt.figure(k+1)
	if len(plotsamps[:,0]) > len(params):
	    #if k==len(params)-1:
            #    plt.hist(plotsamps[:,k],5,label='metric %i'%(j+1))
            #else:
	    plt.hist(plotsamps[:,k],50,label='metric %i'%(j+1),alpha=0.5,normed=True)

for k in range(len(params)):
    plt.figure(k+1)
    plt.legend(loc='best',shadow=False)
    plt.title('Posterior comparison: %s'%(params[k]))
    plt.savefig('PosteriorComp_%s_%s.png'%(datasetlabels[whichdataset-1],params[k]))
plt.show()



