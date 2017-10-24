import sys
sys.path.insert(1,'/Library/Python/2.7/site-packages')
import numpy as np
import matplotlib.pyplot as plt
import corner as triangle
from scipy.stats import beta
from scipy.stats import binom
from scipy.stats import norm as gauss

#DoFinalResampling=False
DoFinalResampling=True

def lnprior(p,whichmodel):
    for i in range(1,ndim):
        if np.any((p[i] > 1.)+(p[i]< 0.)):
            return -np.inf
    lnprior=0.
    if whichmodel == 0:
        return 0.
    for i in range(1,ndim):
        lnprior+=np.log(beta.pdf(p[i],params[i-1][0],params[i-1][1]))
    return lnprior

def drawfromprior(p,whichmodel):
    if whichmodel == 0:
	for i in range(1,ndim):
	    p[i]=np.random.uniform(0.,1.,1)
    else:
	for i in range(1,ndim):
	    p[i]=np.random.beta(params[i-1][0],params[i-1][1])
    return

def modlnprior(i):
   #refmodlnpriors=np.log([(Nagents+1.0)*(Nagents+1.0)/(boxwidth[0]*boxwidth[1]),(Nagents+1.0)/boxwidth[0],(Nagents+1.0)/boxwidth[1],(Nagents+1.0)*(Nagents+1.0)/(boxwidth[0]*boxwidth[1])]) 
   refmodlnpriors=[0.0, 0.0, 0.0, 0.0]
   return refmodlnpriors[i]

def drawfrommodprior():
    pvals=np.ones(nmodels)
    for i in range(nmodels):
	pvals[i]=np.exp(modlnprior(whichincmods[i]))
    pvals=pvals/sum(pvals)
    return np.random.choice(nmodels, p=pvals)

def drawwithinmodel(partprops,whichmodel):
    pvals=partprops[partprops[:,0]==whichmodel][:,ndim]
    if len(pvals) > 0:
	return np.random.choice(len(pvals),p=pvals)
    else:
	return -1

def resamplewithinmodel(partprops,whichmodel):
    nresamp=len(partprops[partprops[:,0]==whichmodel][:,ndim])
    ids=np.zeros(nresamp)
    for i in range(nresamp):
	ids[i]=drawwithinmodel(partprops,whichmodel)
    tmppartprops=np.copy(partprops[partprops[:,0]==whichmodel])
    k=0
    for i in range(nresamp):
        while partprops[k,0] != whichmodel:
	    k=k+1
	partprops[k,0:ndim]=tmppartprops[int(ids[i]),0:ndim]
	partprops[k,ndim]=1.0/nresamp
	k=k+1
    return

def normaliseweights(partprops):
    for i in range(nmodels):
	facts=1.0*np.ones_like(partprops[:,0])
        norm=sum(partprops[partprops[:,0]==i][:,ndim])
	evs[i]=norm
        #print norm,partprops[partprops[:,0]==i][:,ndim]
        for k in range(len(facts)):
	    if partprops[k,0]==i:
		facts[k]=1.0/norm
	partprops[:,ndim]*=facts
        #norm=sum(partprops[partprops[:,0]==i][:,ndim])
        ess=1./sum(partprops[partprops[:,0]==i][:,ndim]*partprops[partprops[:,0]==i][:,ndim])
        print "Effective sample size for model %i is now %f based on %i particles"%(i,ess,len(partprops[partprops[:,0]==i][:,ndim]))
        if ess/(len(partprops[partprops[:,0]==i][:,ndim])) < essth:
	    print "Resampling particles in model %i"%i
	    resamplewithinmodel(partprops,i)
    return

def perturbparticle(p):
    if usepertkern == 0:
        for i in range(1,ndim):
	    u=np.log(p[i]/(1.0-p[i]))
	    unew=u+sigs[i-1]*np.random.normal()
	    p[i]=1.0/(1.0+np.exp(-unew))
	    #print unew,u,p[i]
    elif usepertkern == 1:
	for i in range(1,ndim):
            newp=1.5
            #ndraw=0
	    while np.any((newp > 1.)+(newp< 0.)):
		#ndraw+=1
		newp=p[i]+sigs[i-1]*np.random.normal()
            #print ndraw,p[i],newp
	    p[i]=newp
    return

def pertkernel(pnew,pold):
    pertkern=1.0
    if usepertkern == 0:
        for i in range(1,ndim):
	    unew=np.log(pnew[i]/(1.0-pnew[i]))
	    uold=np.log(pold[i]/(1.0-pold[i]))
	    pertkern*=np.exp(-0.5*(unew-uold)*(unew-uold)/(sigs[i-1]*sigs[i-1]))/(pnew[i]*(1.0-pnew[i]))
        #print pnew,pold,unew,uold,pertkern
    elif usepertkern == 1:
	for i in range(1,ndim):
	    norm=gauss.cdf((1.0-pold[i])/sigs[i-1])-gauss.cdf(-pold[i]/sigs[i-1])
	    pertkern*=np.exp(-0.5*(pnew[i]-pold[i])*(pnew[i]-pold[i])/(sigs[i-1]*sigs[i-1]))
    return pertkern

# Simulate a data set. Note that the return value should be interpreted as "not a valid simulation", i.e., a return value of False means the simulation did give a value in the allowed box
def simulatedataset(p):
    whichmet=whichincmods[int(p[0])]
    lnprob=0.
    if whichmet==0:
	for i in range(1,ndim):
	    r=int((Nagents+1)*np.random.uniform(0,1,1))
	    lnprob+=-0.5*(Nobs[i-1]-r)*(Nobs[i-1]-r)/(thiseps[0][i-1]*thiseps[0][i-1])-np.log(norms[0][i-1])
    else:
        for i in range(1,ndim):
	    r=binom.rvs(Nagents,p[i])
	    lnprob+=-0.5*(Nobs[i-1]-r)*(Nobs[i-1]-r)/(thiseps[whichmet][i-1]*thiseps[whichmet][i-1])-np.log(norms[whichmet][i-1])
    unsamp=np.random.uniform(0,1,1)
    if (np.exp(lnprob) > unsamp):
        return False
    else:
	return True

def softlike(p):
    whichmet=whichincmods[int(p[0])]
    lnprob=0.
    prob=0.
    for rep in range(nrep):
        if whichmet==0:
	    for i in range(1,ndim):
	        r=int((Nagents+1)*np.random.uniform(0,1,1))
	        lnprob+=-0.5*(Nobs[i-1]-r)*(Nobs[i-1]-r)/(thiseps[0][i-1]*thiseps[0][i-1])-np.log(norms[0][i-1])
        else:
            for i in range(1,ndim):
	        r=binom.rvs(Nagents,p[i])
	        lnprob+=-0.5*(Nobs[i-1]-r)*(Nobs[i-1]-r)/(thiseps[whichmet][i-1]*thiseps[whichmet][i-1])-np.log(norms[whichmet][i-1])
	prob+=np.exp(lnprob)
    return (prob/(1.0*nrep))

def plotfigures(level):
    for j in range(nmodels):
        pltwts=partprops[partprops[:,0]==whichincmods[j]][:,ndim]
        for k in range(1,ndim):
            plt.figure((ndim-1)*j+k)
            pltdata=partprops[partprops[:,0]==whichincmods[j]][:,k]
            #plt.hist(pltdata,weights=pltwts,bins=Nparticles/10,normed=True)
            plt.hist(pltdata,weights=pltwts,bins=0.04*np.array(range(26)),normed=True,label='step t = %i'%(level))
    #plt.show()
    #plt.close()

if ((len(sys.argv) != 9)):
    print "Arguments: 1. basename for output files"
    print "           2. show plots on screen (1) or not (0)?"
    print "           3. final epsilon for A"
    print "           4. final epsilon for B"
    print "           5. number of epsilons in sequence"
    print "           6-7. parameters for beta prior, kA and kB (we assume models have priors [kA, kB] and [kB, kA] respectively)"
    print "           8. number of SMC particles"
    exit()
filebasename=sys.argv[1]
showplots=int(sys.argv[2])

ndim=3
nmodelstot=4
params=[[2,5],[5,2]]
#params=[[2,4],[4,2]]
#params=[[2,3],[3,2]]
Nagents=100
Nobs=[10,10]

refeps=[0,0]

refeps[0]=int(sys.argv[3])
refeps[1]=int(sys.argv[4])
Nts=int(sys.argv[5])
params[0][0]=int(sys.argv[6])
params[0][1]=int(sys.argv[7])

Nparticles=int(sys.argv[8])

params[1][0]=params[0][1]
params[1][1]=params[0][0]

boxwidth=1.0*(Nagents+1.0)*np.ones(ndim-1)

epsilon=[[refeps[0],refeps[1]],[refeps[0],100*Nagents],[100*Nagents,refeps[1]],[refeps[0],refeps[1]]]


#nmodels=4
#whichincmods=[0,0,0,0]

#nmodels=1
#whichincmods=[1]
#nmodels=2
#whichincmods=[0,1]
#nmodels=2
#whichincmods=[0,3]
nmodels=4
whichincmods=[0,1,2,3]

norms=0.0*np.ones_like(epsilon)
for i in range(nmodels):
    for k in range(ndim-1):
        for j in range(Nagents+1):
            norms[i][k]+=np.exp(-0.5*(Nobs[k]-j)*(Nobs[k]-j)/(1.0*epsilon[i][k]*epsilon[i][k]))

#sigs=[0.1,0.1]
#usepertkern=0

#sigs=[0.05,0.05]
sigs=[0.1,0.1]
usepertkern=1

nrep=10
updatemodprior=False
#updatemodprior=True
if not updatemodprior:
    for k in range(ndim-1):
        jmin=Nobs[k]-refeps[k]
        jmax=Nobs[k]+refeps[k]
        if (jmin < 0):
           jmin=0
        if (jmax > Nagents): 
           jmax=Nagents
        boxwidth[k]=1.0*(jmax-jmin+1)

essth=0.5

partprops=np.zeros((Nparticles,ndim+1))
nextpartprops=np.zeros((Nparticles,ndim+1))
evs=np.zeros(nmodels)
for i in range(Nparticles):
    partprops[i,0]=drawfrommodprior()
    drawfromprior(partprops[i,:],whichincmods[int(partprops[i,0])])
    partprops[i,ndim]=1.
normaliseweights(partprops)

#print evs
#print partprops
#print partprops[partprops[:,0]==whichincmods[0]][:,ndim]
#print drawwithinmodel(partprops,whichincmods[0])

plotfigures(0)

#for i in range(Nts):
#    thiseps=Nagents*(1.0-(i+1.0)/(1.0*Nts))*np.ones_like(epsilon)+(i+1.0)*np.array(epsilon)/(1.0*Nts)
#    print thiseps
#sys.exit()

for i in range(Nts):
    thiseps=Nagents*(1.0-(i+1.0)/(1.0*Nts))*np.ones_like(epsilon)+(i+1.0)*np.array(epsilon)/(1.0*Nts)
    if updatemodprior:
        for k in range(ndim-1):
            jmin=Nobs[k]-thiseps[0][k]
            jmax=Nobs[k]+thiseps[0][k]
            if (jmin < 0):
               jmin=0
            if (jmax > Nagents):
               jmax=Nagents
            boxwidth[k]=1.0*(jmax-jmin+1)
    for j in range(Nparticles):
	notfound=True
	while notfound:
	    nextpartprops[j,0]=drawfrommodprior()
	    topert=drawwithinmodel(partprops,int(nextpartprops[j,0]))
	    if topert > -1:
		nextpartprops[j,1:ndim]=partprops[partprops[:,0]==int(nextpartprops[j,0])][topert,1:ndim]
            	#print i,j,nextpartprops
		perturbparticle(nextpartprops[j,0:ndim])
		#notfound=simulatedataset(nextpartprops[j,0:ndim])
		notfound=False
		wt=softlike(nextpartprops[j,0:ndim])
            	#print i,j,nextpartprops[j,:],notfound
	oldwt=partprops[partprops[:,0]==int(nextpartprops[j,0])][:,ndim]
	pertkerns=np.ones_like(oldwt)
	for k in range(len(pertkerns)):
	    pertkerns[k]=pertkernel(nextpartprops[j,0:ndim],partprops[partprops[:,0]==int(nextpartprops[j,0])][k,0:ndim])
	#print pertkerns
	#wt=np.exp(lnprior(nextpartprops[j,0:ndim],whichincmods[int(nextpartprops[j,0])]))
	wt*=np.exp(lnprior(nextpartprops[j,0:ndim],whichincmods[int(nextpartprops[j,0])]))
        #print i,j,wt,pertkerns,oldwt,sum(pertkerns*oldwt),partprops
        #if sum(pertkerns*oldwt) == 0.0:
	#    print oldwt,pertkerns,wt,nextpartprops[j,0:ndim],partprops[partprops[:,0]==int(nextpartprops[j,0])][k,0:ndim]
        #    sys.exit()
	nextpartprops[j,ndim]=wt/sum(pertkerns*oldwt)
    #print nextpartprops
    partprops=np.copy(nextpartprops)
    normaliseweights(partprops)
    #Complete one final resampling within the final metric.
    if DoFinalResampling and i==Nts-1:
        nrep=10000
        for j in range(Nparticles):
	    notfound=True
	    while notfound:
	        nextpartprops[j,0]=drawfrommodprior()
	        topert=drawwithinmodel(partprops,int(nextpartprops[j,0]))
	        if topert > -1:
		    nextpartprops[j,1:ndim]=partprops[partprops[:,0]==int(nextpartprops[j,0])][topert,1:ndim]
		    perturbparticle(nextpartprops[j,0:ndim])
		    notfound=False
		    wt=softlike(nextpartprops[j,0:ndim])
	    oldwt=partprops[partprops[:,0]==int(nextpartprops[j,0])][:,ndim]
	    pertkerns=np.ones_like(oldwt)
	    for k in range(len(pertkerns)):
	        pertkerns[k]=pertkernel(nextpartprops[j,0:ndim],partprops[partprops[:,0]==int(nextpartprops[j,0])][k,0:ndim])
	    wt*=np.exp(lnprior(nextpartprops[j,0:ndim],whichincmods[int(nextpartprops[j,0])]))
	    nextpartprops[j,ndim]=wt/sum(pertkerns*oldwt)
    #print partprops
    #print (partprops[partprops[:,0]==whichincmods[0]][:,ndim])
    #print (partprops[partprops[:,0]==whichincmods[1]][:,ndim])
    #print sum(partprops[partprops[:,0]==whichincmods[0]][:,ndim])
    #print sum(partprops[partprops[:,0]==whichincmods[1]][:,ndim])
    #print "End loop",sum(partprops[:,ndim])
    plotfigures(i+1)
    print "At step %i:"%(i+1)
    for j in range(1,nmodels):
        print "Evidence ratio of model %i to model %i: %f"%(whichincmods[j],whichincmods[0],evs[j]/evs[0])
    for j in range(nmodels):
	print "Fraction of particles in model %i is %f"%(j,1.0*len(partprops[partprops[:,0]==j])/(1.0*Nparticles))

#print partprops

for j in range(nmodels):
    for k in range(1,ndim):
        plt.figure((ndim-1)*j+k)
        plt.legend(loc='best',shadow=False)
        plt.title('Model %i, Parameter %i'%(j,k))
        plt.savefig('%s_Posterior_Model%i_Parameter%i.png'%(filebasename,j,k))
plt.show()


