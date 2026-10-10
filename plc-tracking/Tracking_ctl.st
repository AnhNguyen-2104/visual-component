(* ================================================================= *)
(* TRACKING_CTL - PHAN DIEU KHIEN QD75 RIENG (KHONG TINH LAI)          *)
(* Doc tu file tinh Tracking_calc.st qua bien trung gian:             *)
(*  rTargX/Y/Z, dTargX/Y/Z_01um, dSpdStg, iCorner, iState(=10: co phoi)*)
(* Cap vao file tinh: iPhase (1 bay/2 ha/3 nhac), bSegInit (xung chot).*)
(* Thu tu scan: tinh -> sequencer -> handshake -> Y10.                 *)
(* QD75 U0 H0, noi suy ABS linear 3, No.1-12 bay(1,4,7,10)/ha(2,5,8,11)*)
(*  /nhac(3,6,9,12), Da.10 T1 0/11/10, Pr.18 AFTER, Cd.3 G1500,         *)
(*  Cd.7 G1504, Md.25 G808, Y10/X10/X14/X4/XC/XD/XE/X8/X9/XA.           *)
(* ================================================================= *)

(* ---- SEQUENCER: No.1-12 + DTO Da.6/Da.8 + Cd.3 (2 nhip) ---- *)
(* SEQ QD75 U0 H0 - 2 nhip, doc dTarg/dSpdStg tu tinh, khong tinh lai *)
IF SM402 THEN
    wNo := 1;
    wAddrX := 2006;
    wAddrY := 8006;
    wAddrZ := 14006;
    wSpdAddrX := 2004;
    wSpdAddrY := 8004;
    wSpdAddrZ := 14004;
    bFired := FALSE;
    bStartReq := FALSE;
    bRunning := FALSE;
    rTmove := 0.0;
    rTimeoutS := 8.0;
    bPosTimeout := FALSE;
    bSegInit := FALSE;
    iPrevSeq := 0;
END_IF;
IF rTimeoutS <= 0.0 THEN
    rTimeoutS := 8.0;
END_IF;
IF NOT M500 THEN
    bFired := FALSE;
    bStartReq := FALSE;
    bRunning := FALSE;
    rTmove := 0.0;
    bPosTimeout := FALSE;
    bSegInit := FALSE;
    iPrevSeq := 0;
ELSE
    CASE iState OF
        10:
            bPosTimeout := FALSE;
            rTmove := 0.0;
            bFired := FALSE;
            bRunning := FALSE;
            bStartReq := FALSE;
            bSegInit := FALSE;
            IF (iCorner >= 1) AND (iCorner <= 4) THEN
                wNo := (iCorner - 1) * 3 + 1;
            ELSE
                wNo := 1;
            END_IF;
            iPrevSeq := 10;
            iState := 20;
        20:
            IF iState <> iPrevSeq THEN
                bFired := FALSE;
                bRunning := FALSE;
                bStartReq := FALSE;
                rTmove := 0.0;
                bSegInit := TRUE;
                iPrevSeq := iState;
            ELSE
                bSegInit := FALSE;
                rTmove := rTmove + rDt;
                IF NOT bFired THEN
                    IF X0 AND NOT X8 AND NOT X9 AND NOT XA AND NOT bPosTimeout THEN
                        IF (iCorner >= 1) AND (iCorner <= 4) THEN
                            wNo := (iCorner - 1) * 3 + 1;
                            IF (wNo >= 1) AND (wNo <= 12) THEN
                                wAddrX := 2006 + (wNo - 1) * 10;
                                wAddrY := 8006 + (wNo - 1) * 10;
                                wAddrZ := 14006 + (wNo - 1) * 10;
                                wSpdAddrX := 2004 + (wNo - 1) * 10;
                                wSpdAddrY := 8004 + (wNo - 1) * 10;
                                wSpdAddrZ := 14004 + (wNo - 1) * 10;
                                DTO(TRUE, dTargX_01um, H0, wAddrX, K2);
                                DTO(TRUE, dTargY_01um, H0, wAddrY, K2);
                                DTO(TRUE, dTargZ_01um, H0, wAddrZ, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrX, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrY, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrZ, K2);
                                TO(TRUE, wNo, H0, K1500, K1);
                                bFired := TRUE;
                            END_IF;
                        END_IF;
                    END_IF;
                END_IF;
                IF bFired AND NOT bStartReq AND NOT bRunning AND NOT bPosTimeout THEN
                    IF X0 AND NOT XC AND NOT XD AND NOT XE AND NOT X4 THEN
                        bStartReq := TRUE;
                    END_IF;
                END_IF;
                IF rTmove >= rTimeoutS THEN
                    bPosTimeout := TRUE;
                    bStartReq := FALSE;
                END_IF;
            END_IF;
        30:
            IF iState <> iPrevSeq THEN
                bFired := FALSE;
                bRunning := FALSE;
                bStartReq := FALSE;
                rTmove := 0.0;
                bSegInit := TRUE;
                iPrevSeq := iState;
            ELSE
                bSegInit := FALSE;
                rTmove := rTmove + rDt;
                IF NOT bFired THEN
                    IF X0 AND NOT X8 AND NOT X9 AND NOT XA AND NOT bPosTimeout THEN
                        IF (iCorner >= 1) AND (iCorner <= 4) THEN
                            wNo := (iCorner - 1) * 3 + 2;
                            IF (wNo >= 1) AND (wNo <= 12) THEN
                                wAddrX := 2006 + (wNo - 1) * 10;
                                wAddrY := 8006 + (wNo - 1) * 10;
                                wAddrZ := 14006 + (wNo - 1) * 10;
                                wSpdAddrX := 2004 + (wNo - 1) * 10;
                                wSpdAddrY := 8004 + (wNo - 1) * 10;
                                wSpdAddrZ := 14004 + (wNo - 1) * 10;
                                DTO(TRUE, dTargX_01um, H0, wAddrX, K2);
                                DTO(TRUE, dTargY_01um, H0, wAddrY, K2);
                                DTO(TRUE, dTargZ_01um, H0, wAddrZ, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrX, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrY, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrZ, K2);
                                TO(TRUE, wNo, H0, K1500, K1);
                                bFired := TRUE;
                            END_IF;
                        END_IF;
                    END_IF;
                END_IF;
                IF bFired AND NOT bStartReq AND NOT bRunning AND NOT bPosTimeout THEN
                    IF X0 AND NOT XC AND NOT XD AND NOT XE AND NOT X4 THEN
                        bStartReq := TRUE;
                    END_IF;
                END_IF;
                IF rTmove >= rTimeoutS THEN
                    bPosTimeout := TRUE;
                    bStartReq := FALSE;
                END_IF;
            END_IF;
        50:
            IF iState <> iPrevSeq THEN
                bFired := FALSE;
                bRunning := FALSE;
                bStartReq := FALSE;
                rTmove := 0.0;
                bSegInit := TRUE;
                iPrevSeq := iState;
            ELSE
                bSegInit := FALSE;
                rTmove := rTmove + rDt;
                IF NOT bFired THEN
                    IF X0 AND NOT X8 AND NOT X9 AND NOT XA AND NOT bPosTimeout THEN
                        IF (iCorner >= 1) AND (iCorner <= 4) THEN
                            wNo := (iCorner - 1) * 3 + 3;
                            IF (wNo >= 1) AND (wNo <= 12) THEN
                                wAddrX := 2006 + (wNo - 1) * 10;
                                wAddrY := 8006 + (wNo - 1) * 10;
                                wAddrZ := 14006 + (wNo - 1) * 10;
                                wSpdAddrX := 2004 + (wNo - 1) * 10;
                                wSpdAddrY := 8004 + (wNo - 1) * 10;
                                wSpdAddrZ := 14004 + (wNo - 1) * 10;
                                DTO(TRUE, dTargX_01um, H0, wAddrX, K2);
                                DTO(TRUE, dTargY_01um, H0, wAddrY, K2);
                                DTO(TRUE, dTargZ_01um, H0, wAddrZ, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrX, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrY, K2);
                                DTO(TRUE, dSpdStg, H0, wSpdAddrZ, K2);
                                TO(TRUE, wNo, H0, K1500, K1);
                                bFired := TRUE;
                            END_IF;
                        END_IF;
                    END_IF;
                END_IF;
                IF bFired AND NOT bStartReq AND NOT bRunning AND NOT bPosTimeout THEN
                    IF X0 AND NOT XC AND NOT XD AND NOT XE AND NOT X4 THEN
                        bStartReq := TRUE;
                    END_IF;
                END_IF;
                IF rTmove >= rTimeoutS THEN
                    bPosTimeout := TRUE;
                    bStartReq := FALSE;
                END_IF;
            END_IF;
        45:
            IF iState <> iPrevSeq THEN
                rTmove := 0.0;
                bSegInit := FALSE;
                iPrevSeq := iState;
            ELSE
                bSegInit := FALSE;
                rTmove := rTmove + rDt;
                IF rTmove >= rTimeoutS THEN
                    bPosTimeout := TRUE;
                    bStartReq := FALSE;
                END_IF;
            END_IF;
        55:
            IF iState <> iPrevSeq THEN
                rTmove := 0.0;
                bSegInit := FALSE;
                iPrevSeq := iState;
            ELSE
                bSegInit := FALSE;
                rTmove := rTmove + rDt;
                IF rTmove >= rTimeoutS THEN
                    bPosTimeout := TRUE;
                    bStartReq := FALSE;
                END_IF;
            END_IF;
        ELSE
            bSegInit := FALSE;
            iPrevSeq := iState;
    END_CASE;
END_IF;

(* ---- HANDSHAKE: M-code / van keo / Y10-X10 / tat M (Cd.7) ---- *)
(* Doc rTarg/iState qua bien trung gian tu file tinh; KHONG DTO, KHONG tinh lai. *)
(* Sequencer giu wNo/Da.6/Da.8/Cd.3/bFired-nhip1/bStartReq-nhip2/timeout;      *)
(*  slice nay ghi iState CHI 20->30/30->40/40->45/45->50/50->55/55->10-hoac-0. *)
(* Scan: tinh -> sequencer -> handshake -> Y10.                                *)

(* 0. Doc M-code truc 1 (Md.25 U0\G808) moi scan *)
FROM(TRUE, H0, K808, K1, wMcode);

(* 0b. Mac dinh thoi gian phun neu tag = 0 (INIT chinh dat 0.6) *)
IF rDwellS <= 0.0 THEN
    rDwellS := 0.6;
END_IF;

(* 1. CLEAR M TRUOC START (rung 257): chua fire ma X4 con ON -> xin tat M truoc *)
(* Chi DOC bFired (sequencer so huu), KHONG ghi bFired/bRunning/rTmove o slice nay *)
IF M500 AND NOT bFired AND X4 THEN
    bMOffReq := TRUE;
END_IF;

(* 2. CHUYEN STATE + VAN + DWELL (IF/ELSIF trong IF M500: 1 state/scan) *)
IF M500 THEN
    IF iState = 20 THEN
        IF bRunning AND X14 THEN
            iPhase := 2;
            iState := 30;
        END_IF;
    ELSIF iState = 30 THEN
        bValve := FALSE;
        IF X4 AND (wMcode = 11) THEN
            bValve := TRUE;
            rTdwell := 0.0;
            iState := 40;
        END_IF;
    ELSIF iState = 40 THEN
        rTdwell := rTdwell + rDt;
        IF rTdwell >= rDwellS THEN
            bValve := FALSE;
            bMOffReq := TRUE;
            iState := 45;
        END_IF;
    ELSIF iState = 45 THEN
        IF NOT X4 THEN
            iPhase := 3;
            iState := 50;
        END_IF;
    ELSIF iState = 50 THEN
        bValve := FALSE;
        IF X4 AND (wMcode = 10) THEN
            bMOffReq := TRUE;
            iState := 55;
        END_IF;
    ELSIF iState = 55 THEN
        IF NOT X4 THEN
            IF iCorner < 4 THEN
                iCorner := iCorner + 1;
                iPhase := 1;
                iState := 10;
            ELSE
                bActive := FALSE;
                iPhase := 1;
                iState := 0;
            END_IF;
        END_IF;
    END_IF;
END_IF;

(* 3. TAT M (Cd.7 U0\G1504): ghi K1; QD75 tu clear G1504=0 sau X4 OFF, KHONG ghi K0 de *)
IF bMOffReq THEN
    wTmp := 1;
    TO(TRUE, wTmp, H0, K1504, K1);
    IF NOT X4 THEN
        bMOffReq := FALSE;
    END_IF;
END_IF;

(* 4. XUNG Y10 1 shot + nhan X10 (DUY NHAT 1 dong gan Y10 toan chuong trinh; chi SET bRunning) *)
Y10 := bStartReq AND X0 AND NOT X10;
IF bStartReq AND X0 AND X10 THEN
    bStartReq := FALSE;
    bRunning := TRUE;
END_IF;
