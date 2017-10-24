import sys
sys.path.insert(1,'/Library/Python/2.7/site-packages')
import numpy as np
import matplotlib.pyplot as plt
import emcee
import corner as triangle
from datetime import datetime
from scipy.stats import beta
from scipy.stats import binom

def lnprior(p):
    for i in range(ndim):
        if np.any((p[i] > 1.)+(p[i]< 0.)):
            return -np.inf
    lnprior=0.
    if int(nmodels*p[0]) == 0:
	return modlnprior[0]
    for i in range(1,ndim):
        lnprior+=np.log(beta.pdf(p[i],params[i-1][0],params[i-1][1]))
    lnprior+=(modlnprior[int(nmodels*p[0])])
    return lnprior

def lnlike(p):
    smalllnl=-1000000.
    whichmet=int(nmodels*p[0])
    nreal=1
    like=0.
    for k in range(nreal):
        lnlike=0.
        if whichmet == 0:
            for i in range(1,ndim):
                r=int((Nagents+1)*np.random.uniform(0,1,1))
                if np.abs(Nobs[i-1]-r) > epsilon[whichmet][i-1]:
                    lnlike+=smalllnl
        else:
            for i in range(1,ndim):
                r=binom.rvs(Nagents,p[i])
                if np.abs(Nobs[i-1]-r) > epsilon[whichmet][i-1]:
	            lnlike+=smalllnl
        like+=np.exp(lnlike)
    #print like,nreal
    if like == 0.0:
        lnlike=smalllnl
    else:
        lnlike=np.log(like/(1.0*nreal))
    return lnlike

def analyticlnlike(p):
    lnlike=0.
    whichmet=int(nmodels*p[0])
    if whichmet == 0:
        lnlike=np.log(boxwidth[0]*boxwidth[1]/((Nagents+1.0)*(Nagents+1.0)))
    else:
        for i in range(1,ndim):
            jmin=Nobs[i-1]-epsilon[whichmet][i-1]
    	    jmax=Nobs[i-1]+epsilon[whichmet][i-1]
    	    if (jmin < 0):
                jmin=0
    	    if (jmax > Nagents):
        	jmax=Nagents
            thisprob=0.
	    for k in range(jmin,jmax+1):
                thisprob+=binom.pmf(k,Nagents,p[i])
	    if thisprob > 0.:
		lnlike+=np.log(thisprob)
	    else:
		lnlike=-np.inf
    #print whichmet,lnlike
    return lnlike

def lnprob(p):
    #if int(nmodels*p[0])==0:
    #    return 0.
    prival=lnprior(p)
    if (prival == -np.inf):
        return -np.inf
    val=prival+lnlike(p)
    #val=prival+analyticlnlike(p)
    #print int(nmodels*p[0]),prival,val
    return val

if ((len(sys.argv) != 8)):
    print "Arguments: 1. basename for output files"
    print "           2. show plots on screen (1) or not (0)?"
    print "           3. epsilon for A"
    print "           4. epsilon for B"
    print "           5-6. parameters for beta prior, kA and kB (we assume models have priors [kA, kB] and [kB, kA] respectively)"
    print "           7. number of MCMC iterations"
    exit()
filebasename=sys.argv[1]
showplots=int(sys.argv[2])

ndim=3
nmodels=4
params=[[2,5],[5,2]]
#params=[[2,4],[4,2]]
#params=[[2,3],[3,2]]
Nagents=100
Nobs=[10,10]

refeps=[0,0]

refeps[0]=int(sys.argv[3])
refeps[1]=int(sys.argv[4])
params[0][0]=int(sys.argv[5])
params[0][1]=int(sys.argv[6])

MCMCits=int(sys.argv[7])

params[1][0]=params[0][1]
params[1][1]=params[0][0]

boxwidth=np.zeros(ndim-1)
for i in range(ndim-1):
    jmin=Nobs[i]-refeps[i]
    jmax=Nobs[i]+refeps[i]
    if (jmin < 0):
        jmin=0
    if (jmax > Nagents):
        jmax=Nagents
    boxwidth[i]=1.0*(jmax-jmin+1)

#modlnprior=np.log([(Nagents+1.0)*(Nagents+1.0)/((2.*refeps[0]+1.)*(2.*refeps[1]+1.)),(Nagents+1.0)/(2.*refeps[0]+1.),(Nagents+1.0)/(2.*refeps[1]+1.),(Nagents+1.0)*(Nagents+1.0)/((2.*refeps[0]+1.)*(2.*refeps[1]+1.))])
modlnprior=np.log([(Nagents+1.0)*(Nagents+1.0)/(boxwidth[0]*boxwidth[1]),(Nagents+1.0)/boxwidth[0],(Nagents+1.0)/boxwidth[1],(Nagents+1.0)*(Nagents+1.0)/(boxwidth[0]*boxwidth[1])])
print modlnprior
#sys.exit()

epsilon=[[refeps[0],refeps[1]],[refeps[0],Nagents],[Nagents,refeps[1]],[refeps[0],refeps[1]]]

nwalkers = 36
sampler = emcee.EnsembleSampler(nwalkers, ndim, lnprob)
p0=[np.random.uniform(0,1,ndim) for i in range(nwalkers)]
#p0=[beta.rvs(params[:][0],params[:][1]) for i in range(nwalkers)]
print("Running burn-in")
#print p0
#lnpr=0.*np.ones_like(p0)
lnpr=[0. for i in range(nwalkers)]
for i in range(nwalkers):
    lnpr[i]=lnprior(p0[i])+analyticlnlike(p0[i])
lnprob0=np.array(lnpr)
#print lnprob0
#p0, _, _ = sampler.run_mcmc(p0, 1000,lnprob0=lnprob0)
p0, _, _ = sampler.run_mcmc(p0, 10000)
#p0, _, _ = sampler.run_mcmc(p0, 1000)
print("Running production chain")
lnpr=[0. for i in range(nwalkers)]
for i in range(nwalkers):
    lnpr[i]=lnprior(p0[i])+analyticlnlike(p0[i])
lnprob0=np.array(lnpr)
#sampler.run_mcmc(p0, 1000,lnprob0=lnprob0)
sampler.run_mcmc(p0, MCMCits)
#sampler.run_mcmc(p0, 100)
#samples=sampler.flatchain[20000:100000,:]
samples=sampler.flatchain

labels=[r"$p_A$",r"$p_B$"]
evidences=[i for i in range(nmodels)]
#print int(x[0]*nmodels)
for i in range(nmodels):
    subsample=samples[(nmodels*samples[:,0] >= i) & (nmodels*samples[:,0] < i+1)]
    evidences[i]=len(subsample[:,0])*(1./len(samples[:,0]))
    #evidences[i]=(sum(1 for x in samples[:,0] if int(x*nmodels)==i))*(1./len(samples[:,0]))
    if i > 0:
        print "For model",i," evidence =",evidences[i]/evidences[0]
        fig = triangle.corner(subsample[:,1:3], labels=labels)
        fig.savefig("%s_Triangle_Model%i.png"%(filebasename,i),dpi=150)

if showplots:
    plt.show()


