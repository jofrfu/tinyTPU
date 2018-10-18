% Values greater 5.125 --> 255
X = [0:0.03125:5.125];
Y = 1./(1+exp(-X));
Y = round(Y);
Y = 1./(1+exp(-X));
Y = Y.*256;
Y = round(Y);
csvwrite('quantized_sigmoid_unsigned.csv', Y);
stem(X,Y);