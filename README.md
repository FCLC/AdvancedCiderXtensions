#  Advanced Cider eXtensions

Simple swift program meant to test the various GEMM implementations available under the Apple's Accelerate implementation of the BLAS spec.

The initial version (released late 2023) tests solely "all core" DGEMM performance. Accelerate's BLAS implementation is "always" multi threaded, and will always use all SOC devices when available. This can be AVX1/2/512f on Intel based Macs, or it can be Helium, Neon, ASIMD, {top secret thing}, and I hope eventually SVE and SME

## How do?

### easy mode: 

1. open the Xcode project,
2. build
3. provide the amount of memory in GBs your device has, followed by hitting return/enter
4. post your results *and* your device config!!!

### Slightly harder: 

1. open your terminal 
2. git clone this repo
3. navigate to main.swift 
4. `swiftc main.swift -o a.out -O`
5. `./a.out` 
6. enter amount of memory on device when prompted
7. post your results *and* your device config!!!

## what should I send you? 

the last 2 lines as indicated in the program and the device you ran this on.
format should be: device year, device model, device CPU config, device memory config 
ex: 2023, Macbook Pro 16 inch, M3Max, 128GB. 

### if you're not sure: 

#### About this Mac 

    1. move your cursor to the top left of the screen
    2. click the small apple logo 
    3. click about this mac
    3.  A. if the information isn't clear to you, proceed to step 4
    3.  B. if it is clear, fill out the above information using the about this mac menu
     
    4.  A. take a screen shot of the relevant information WITHOUT YOUR SERIAL NUMBER
    4.  B. you can hit command+shift+4 to open up the mac screenshoting menu. 
    4.  C. this screen shot will be deposited on the desktop 


Full example from the machine I'm running this on: 
```

[2, 3, 4, 8, 9, 10, 16, 27, 32, 64, 81, 100, 128, 243, 256, 512, 729, 1000, 1024, 2048, 2187, 4096, 6561, 8192, 10000, 16384, 19683]
[0.00014707639699596458, 0.003494919422691088, 0.008749743659853716, 0.06790450928381962, 0.18623068080214586, 0.23637867864318637, 0.03283695761098306, 0.6306228373702422, 0.5864991363957723, 2.010221961497023, 5.162478264670741, 6.7476838575159075, 9.710475626018669, 23.529780147879944, 38.91564596658684, 27.516054481152043, 52.14393076879697, 87.7603223471744, 97.92763250176978, 102.69577127634074, 105.506825019667, 81.476686380203, 96.93331916634915, 93.60439988468656, 90.7582806546308, 85.63913456839335, 85.54126369380319]
2015,Macbook Pro Retina 15'inch, 2.5 GHz Quad-Core Intel Core i7, 16 GBs'
```




## What are we actually doing? (the long technical part)

The program flow is rather simple: 

A user inputs the amount of memory or RAM that they want to test for. Typically this will either be the maximum installed on the device, or for quick/small tests, some smaller integer. 

From there, that number is multiflied by 1B to give us the amount of Bytes we have to play with. 

Using the number of bytes, we calculate what powers of 2, 3, and 10 can be used as the matrix dimensions.

The math here is relatively simple: Because we're testing FP64 performance, each entry needs 8 Bytes.
So divide input bytes by 8

Because DGEMM is defined as `C[][]=A[][]*B[][] + C[][]` we know we need 3 arrays. 

So data points per array = total data points divided by 3

And since we're looking for the edge dimensions of a square matrix, we can simply take the SquareRoot of data point per array

Edge width = squareroot(data_point per array)

Great! Now we know the upper bound of how big our matrices can be. 

Now we want to know all the powers of N (where N is the power to raise {2,3,10} to) that will be within the range of our matricies. 

Simple solution here: Logarithm to the rescue! take the Log2(edge length), truncate to integer values and now you know! Repeat for log3 and log10. 

Now fill an array called tests with N^(1->(integer truncation of logN(edge length))), run a sort on the result array and we have the edge lengths of all the powers we want to test for in a nice, ordered set from smallest to largest!


Since we don't want any major shortcuts to be taken in terms of data (sparse matrix Zeroing for example), alocate an array with random data between 2 points (I chose e and pi, it doesn't really mater). Then copy a scaled version those results to Array B `(B[i]=A[i]*2)` and an additive version to Array C `(C[i]=A[i]+1)`. 

We could absolutely do full RNG for all 3 arrays, it just takes forever. 

For that same reason, we only allocate the results once, then use it for all small matricies. This has the added benefit of effectively changing all the data in C and not being terribly cache friendly between MatMul tests. 

Also on the topic of matmul tests, between the actual data allocation to the arrays, we ask the system to make the process sleep for 10 seconds. This lowers the instantaneous power draw for a few moments, freeing up boosting headroom. We pull the same trick between tests, sleeping for 2 seconds instead. 

At the start of a test, we take a high resolution timestamp, and do the same thing once the function returns. From there we can use the natural algorithmic complexity of square Matrix Multiplication, namely O((edge_legnth)^3) to calculate how many operations are required to solve the given matrix. 

Given total operations needed and time taken, you can then produce a result in FLOPS (FLoating Operations Per Second). Because modern computers are relatively fast, we express this in GigaFLOPS or GFLOPS. 

(Bonus points for the lazy: Because we use nanosecond timers and GFLOPS, the 10^9 and 10^-9 components cancel out, no conversion needed)

for the sake of the user, print out the GFLOPS achieved for every given entry, while also storing the result in an array 

At the end print out a message that's easy to copy and paste to share


