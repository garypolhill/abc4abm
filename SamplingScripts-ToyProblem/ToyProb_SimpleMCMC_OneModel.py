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
    for i in range(ndim):
        lnprior+=np.log(beta.pdf(p[i],params[i][0],params[i][1]))
    return lnprior

def lnlike(p):
    lnlike=0.
    smalllnl=-1000000.
    for i in range(ndim):
        r=binom.rvs(Nagents,p[i])
        if np.abs(Nobs[i]-r) > epsilon[i]:
	    lnlike+=smalllnl
    return lnlike

def analyticlnlike(p):
    lnlike=0.
    for i in range(ndim):
        lnlike+=binom.pmf(Nobs[i],Nagents,p[i])
    return lnlike

def lnprob(p):
    prival=lnprior(p)
    if (prival == -np.inf):
        return -np.inf
    val=prival+lnlike(p)
    return val

if ((len(sys.argv) != 5)):
    print "Arguments: 1. basename for output files"
    print "           2. show plots on screen (1) or not (0)?"
    print "           3. epsilon for A"
    print "           4. epsilon for B"
    exit()
filebasename=sys.argv[1]
showplots=int(sys.argv[2])


ndim=2
params=[[2,5],[5,2]]
Nagents=100
Nobs=[10,10]

#epsilon=[0,100]
#epsilon=[2,100]
#epsilon=[5,100]
#epsilon=[10,100]
#epsilon=[100,0]
#epsilon=[100,2]
#epsilon=[100,5]
#epsilon=[100,10]
epsilon=[0,0]
#epsilon=[2,2]
#epsilon=[5,5]
#epsilon=[10,10]
#epsilon=[100,100]

epsilon[0]=int(sys.argv[3])
epsilon[1]=int(sys.argv[4])

nwalkers, ndim = 36, 2
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
print("Running production chain")
lnpr=[0. for i in range(nwalkers)]
for i in range(nwalkers):
    lnpr[i]=lnprior(p0[i])+analyticlnlike(p0[i])
lnprob0=np.array(lnpr)
#sampler.run_mcmc(p0, 1000,lnprob0=lnprob0)
sampler.run_mcmc(p0, 100000)
#samples=sampler.flatchain[20000:100000,:]
samples=sampler.flatchain

labels=[r"$p_A$",r"$p_B$"]
fig = triangle.corner(samples, labels=labels)
fig.savefig("%s_Triangle.png"%(filebasename),dpi=150)
if showplots:
    plt.show()


