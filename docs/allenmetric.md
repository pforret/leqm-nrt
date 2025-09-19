# Allen Metric Calculations

```bash
leqm-nrt soundtrack.wav --buffersize 750 --logleqm10
```

With the command above:

1) The program calculates Leq(M) for each 750 ms of the soundtrack and store the values in an array

2) A sliding average (sum of Leq(m) values divided by number of 750ms segment in 10 minutes, that is 800) is calculated for time span of 10 minutes and values are stored in an array and logged into a text file

3) Values from point 2 are summed together if averaged value is more than threshold (default 80), otherwise discarded.

4) The sum is divided by the duration of the soundtrack in minutes


Output of 4 would be the Allen Metric as I understand it from the article.


