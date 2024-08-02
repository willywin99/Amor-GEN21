CREATE OR REPLACE PROCEDURE PRC_GET_AMORT_PO (AD_DATE DATE)  IS
/******************************************************************************
   NAME:       PRC_GET_AMORT_PO
   PURPOSE:    TO GET AMOR VALUE OF RUN AIRED

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/17/2009          1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     PRC_GET_AMORT_PO
      Sysdate:         4/17/2009
      Date and Time:   4/17/2009, 2:47:40 PM, and 4/17/2009 2:47:40 PM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
LD_DATE_FROM    DATE;
LD_DATE_TO      DATE;
LL_COUNT        NUMBER;
ll_amort_val    number;

cursor c1 (LD_DATE_FROM DATE, LD_DATE_TO DATE) is
SELECT H.PUR_CONTRACT_NO ,
           H.REVISION_NO,
           H.PUR_TYPE,
           H.PO_SUB_GRP,
           A.FILM_TITLE,
           A.PROG_ID,
           B.ROW_ID_FILM
   --        SUM(NVL(C.AMOR_HOME_VAL,0)) CURR_AMOR_VAL
    FROM PURCHASE_CONTRACT_HDR H,
         PURCHASE_CONTRACT_DTL A,
         PUR_EPISODE_HDR B,
         RUN_MASTER C
    WHERE ( H.PUR_CONTRACT_NO   = A.PUR_CONTRACT_NO ) AND
         ( H.REVISION_NO        = A.REVISION_NO ) AND
         ( H.REVISION_NO        = ( SELECT MAX(REVISION_NO)
                                     FROM PURCHASE_CONTRACT_HDR HDR
                                     WHERE HDR.PUR_CONTRACT_NO = H.PUR_CONTRACT_NO    )) AND
         ( A.PUR_CONTRACT_NO    = B.PUR_CONTRACT_NO ) AND
         ( A.REVISION_NO        = B.REVISION_NO ) AND
         ( A.ROW_ID             = B.ROW_ID_FILM ) AND
         ( B.ROW_ID             = C.ROW_ID_EPI ) AND
          ( ( ( NVL(C.RUN_AIRED,'N') = 'Y') AND
              ( C.LAST_DATE  BETWEEN ADD_MONTHS( LD_DATE_FROM, -5)  AND LD_DATE_TO  )  AND
              ( c.last_date <= LD_DATE_TO) /*and
              ( c.last_date > to_date('20120731','yyyymmdd'))*/ ) OR
            (EXISTS(SELECT 1 FROM RUN_MASTER_RUN_HIST RH
                          WHERE RH.ROW_ID_RUN = C.ROW_ID AND
                          ( NVL(C.RUN_AIRED,'N') = 'Y') AND
                          ( RH.LAST_DATE  BETWEEN ADD_MONTHS( LD_DATE_FROM, -5)  AND LD_DATE_TO  )  AND
                          ( RH.last_date <= LD_DATE_TO) /*and
                          ( RH.last_date > to_date('20120731','yyyymmdd'))*/))
         ) and
         ( c.last_date > to_date('20240430','YYYYMMDD')) and --Remark Modify - Ridwan, ( c.last_date > '31-May-2009') and
          ( H.PO_SUB_GRP IN ('I','O','C') ) AND
      --    A.PROG_GROUP IN (SELECT PROG_GROUP FROM PO_RESTRICTION where nvl(send_amort,'N') = 'Y')
         ((A.PROG_GROUP,H.PUR_TYPE,H.PO_SUB_GRP) not IN (SELECT prog_group,MAJOR,SOURCE FROM PO_RESTRICTION) --where nvl(send_amort,'N') = 'Y'
           or a.prog_group is null) --and
         --  NOT EXISTS (select 1 from film_sharing_amor F WHERE F.GEN_ROW_ID = C.ROW_ID) --AND
    GROUP BY H.PUR_CONTRACT_NO ,
           H.REVISION_NO,
           H.PUR_TYPE,
           H.PO_SUB_GRP,
           A.FILM_TITLE,
           A.PROG_ID,
           B.ROW_ID_FILM
    order by H.PUR_CONTRACT_NO ,
           H.REVISION_NO;

BEGIN
   LL_COUNT := 0 ;
   --GET LAST MONTH
   SELECT TRUNC(LAST_DAY(ADD_MONTHS(AD_DATE, -1)))
   INTO LD_DATE_TO
   FROM DUAL ;

   LD_DATE_FROM := TO_DATE( TO_CHAR(LD_DATE_TO,'YYYYMM')||'01','YYYYMMDD') ;

   DELETE FROM t_amort_po2;

    for x in c1(LD_DATE_FROM,LD_DATE_TO) loop
       select SUM(NVL(a.AMOR_HOME_VAL,0)) CURR_AMOR_VAL
       into ll_amort_val
       from run_master a
       where a.PUR_CONTRACT_NO = x.pur_contract_no
         and a.REVISION_NO = x.revision_no
         and a.ROW_ID_FILM = x.row_id_film
         and NVL(a.RUN_AIRED,'N') = 'Y'
      and last_date <= LD_DATE_TO
      AND LAST_DATE > to_date('20240430','YYYYMMDD'); --Remark Modify - Ridwan, AND LAST_DATE > '31-MAY-2009';

       insert into t_amort_po2
       (PO_NO, REV_NO, MAJOR, SOURCE, PROG_NAME,
           PROG_ID, ROW_ID_FILM, AMOR_VALUE)
       values
       (x.PUR_CONTRACT_NO ,x.REVISION_NO,x.PUR_TYPE,x.PO_SUB_GRP,x.FILM_TITLE,
        x.PROG_ID,x.ROW_ID_FILM,ll_amort_val);
    end loop;

    UPDATE T_AMORT_PO T1
    SET T1.AMOR_CURR_MONTH  = (SELECT T2.AMOR_VALUE
                                FROM t_amort_po2 T2
                                WHERE T2.PO_NO   = T1.PO_NO AND
                                      T2.REV_NO  = T1.REV_NO AND
                                      T2.PROG_ID = T1.PROG_ID ),
        T1.AIRED_DATE       = LD_DATE_TO,
        T1.GEN21_TIMEST     = SYSDATE
    WHERE T1.REV_FLAG = ' '
          AND EXISTS (SELECT 1 FROM t_amort_po2 T2
                   WHERE T2.PO_NO   = T1.PO_NO AND
                         T2.REV_NO  = T1.REV_NO AND
                         T2.PROG_ID = T1.PROG_ID ) ;

    INSERT INTO T_AMORT_PO
       (PO_NO, REV_NO, MAJOR, SOURCE, PROG_NAME,
        PROG_ID, ROW_ID_FILM, AIRED_DATE, AMOR_PREV_MONTH, AMOR_CURR_MONTH,
        ROW_ID, GEN21_TIMEST,REV_FLAG)
    SELECT PO_NO, REV_NO, MAJOR, SOURCE, PROG_NAME,
           PROG_ID, ROW_ID_FILM, LD_DATE_TO, 0, AMOR_VALUE,
           GET_ROW_ID(), SYSDATE, ' '
    FROM t_amort_po2 T2
    WHERE  NOT EXISTS (SELECT 1 FROM T_AMORT_PO T1
                        WHERE T1.PO_NO   = T2.PO_NO AND
                              T1.REV_NO  = T2.REV_NO AND
                              T1.PROG_ID = T2.PROG_ID AND
                              T1.REV_FLAG = ' ' ) ;

    UPDATE PURCHASE_CONTRACT_DTL A
    SET A.SAP_AMOR = (SELECT T2.AMOR_VALUE
                        FROM t_amort_po2 T2
                        WHERE T2.PO_NO  = A.PUR_CONTRACT_NO AND
                              T2.REV_NO = A.REVISION_NO AND
                              T2.ROW_ID_FILM = A.ROW_ID )
    WHERE EXISTS (SELECT 1
                  FROM t_amort_po2 T2
                  WHERE T2.PO_NO  = A.PUR_CONTRACT_NO AND
                       T2.REV_NO = A.REVISION_NO AND
                       T2.ROW_ID_FILM = A.ROW_ID )  ;

    COMMIT ;

END PRC_GET_AMORT_PO;
 
 
/

