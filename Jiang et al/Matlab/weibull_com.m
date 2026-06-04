function f = weibull_com(x)
beta = 894.16;
eta = 0.99805;
f = (beta/eta)*(x/eta).^(beta-1).*exp(-(x/eta).^beta);
end