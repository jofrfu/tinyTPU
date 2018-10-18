% Values lower -5.5 --> 0; Greater 4.375 --> 127
X = [-5.5:0.0625:4.375];
Y = 1./(1+exp(-X));
Y = round(Y);
Y = 1./(1+exp(-X));
Y = Y.*128;
Y = round(Y);
csvwrite('quantized_sigmoid_signed.csv', Y);
stem(X,Y);