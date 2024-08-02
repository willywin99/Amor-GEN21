CREATE OR REPLACE PROCEDURE MENTARITV_LIVE.PRC_GET_AMORT_PO_V2 (AD_DATE DATE)  IS
/******************************************************************************
   NAME:       PRC_GET_AMORT_PO
   PURPOSE:    TO GET AMOR VALUE OF RUN AIRED

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
                                           ANTV
******************************************************************************/
LD_DATE_FROM    DATE;
LD_DATE_TO      DATE;
LL_COUNT        NUMBER;
ll_amort_val    NUMERIC(18,2);
ll_amort_val_old    NUMERIC(18,2);
ll_amort_val_new    NUMERIC(18,2);
LS_TEXT     VARCHAR2(200);
ERR_CODE    VARCHAR2(50);
ERR_NAME    VARCHAR2(100);
ERR_MSG     VARCHAR2(500);
LS_ROW_ID   VARCHAR2(18);
major_sap VARCHAR2(6);
source_code_sap VARCHAR2(6);
ls_prog_category_sap varchar2(254);
ls_sub_category_sap varchar2(254);
i               NUMBER;
ii              NUMBER;
iii             NUMBER;

cursor c1 (LD_DATE_FROM date,LD_DATE_TO      DATE) is

SELECT H.PUR_CONTRACT_NO ,
           H.REVISION_NO,
           H.PUR_TYPE,
           H.PO_SUB_GRP,
           substr(A.FILM_TITLE,1,30) as FILM_TITLE,
           A.PROG_ID,
           B.ROW_ID_FILM,
           B.FILM_EPI_TITLE as FILM_EPI_TITLE,
           B.EPI_NO,
           B.ROW_ID as ROW_ID_EPI,
           C.LAST_DATE,
           C.LAST_TIME,
           C.RUN_ID,
           nvl(C.AMOR_HOME_VAL,0) as AMOR_HOME_VAL
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
              ( c.last_date <= LD_DATE_TO)  ) OR
            (EXISTS(SELECT 1 FROM RUN_MASTER_RUN_HIST RH
                          WHERE RH.ROW_ID_RUN = C.ROW_ID AND
                          ( NVL(C.RUN_AIRED,'N') = 'Y') AND
                          ( RH.LAST_DATE  BETWEEN ADD_MONTHS( LD_DATE_FROM, -5)  AND LD_DATE_TO  )  AND
                          ( RH.last_date <= LD_DATE_TO)))
         ) and
         ( c.last_date > '31-Dec-2016')
         --and ( to_char(H.PUR_CONTRACT_DATE,'YYYYMM')) >= '201701'
    order by H.PUR_CONTRACT_NO ,
           H.REVISION_NO,
           A.PROG_ID,
           B.EPI_NO,
           C.RUN_ID
           ;

BEGIN
   LL_COUNT := 0 ;
   --GET LAST MONTH
   SELECT TRUNC(LAST_DAY(ADD_MONTHS(AD_DATE, -1)))
   INTO LD_DATE_TO
   FROM DUAL ;

   LD_DATE_FROM := TO_DATE( TO_CHAR(LD_DATE_TO,'YYYYMM')||'01','YYYYMMDD') ;


    for x in c1(LD_DATE_FROM,LD_DATE_TO) loop
    BEGIN
      LS_TEXT       := 'AMORTIZATION FOR MONTH : '|| TO_CHAR(x.LAST_DATE, 'MONTHYYYY')   ;

      -- LDEC_AMOUNT   := ROUND(:NEW.AMOR_CURR_MONTH - :NEW.AMOR_PREV_MONTH) ;
      --pur_adjustment_runs

      IF x.AMOR_HOME_VAL <> 0 THEN
         LS_ROW_ID  :=  GET_ROW_ID();

         SELECT COUNT(1)  INTO i
           FROM SYN_G_SAP_AMRTIZATION_V2
          WHERE REF_NO = x.PUR_CONTRACT_NO
            AND row_id_epi= x.row_id_epi
            AND run_id = x.run_id
          --  AND trans_type='C'
            ;


               --- If Episode not in GRM_MP TABLE then follwoing
        IF i=0  THEN

         begin
           select a.sap_code
              into source_code_sap
              from INV_SUB_GROUP a
              where a.PO_SUB_GRP = x.PO_SUB_GRP;
         exception
          when others then
            raise_application_error(-20001,'source '||sqlerrm);
         end;

         begin
           select a.sap_code
              into major_sap
              from INV_PO_TYPE a
              where a.PO_TYPE = x.PUR_TYPE;
         exception
          when others then
            raise_application_error(-20001,'major'||sqlerrm);
         end;

         BEGIN
          INSERT INTO SYN_G_SAP_AMRTIZATION_V2
           (TRANS_TYPE, REF_NO, ASSIGNMENT, DOC_HDR_TXT, DOC_DATE,
            CURRENCY, PO_SOURCE, PO_MAJOR, FLG_REVSH, AMOUNT,
            TEXT1, GEN21_TIMEST, SAP_TIMEST, ROW_ID,PLAY_DATE,
            FILM_TITLE, FILM_EPI_TITLE, EPI_NO, ROW_ID_FILM,
            ROW_ID_EPI, PROG_ID, PLAY_TIME, FLAG, SEND_REMARK, RUN_ID)
           VALUES('C',x.PUR_CONTRACT_NO, x.PROG_ID, substr(x.film_title,1,30), to_char(LD_DATE_TO,'YYYYMMDD'),
                  'IDR', source_code_sap, major_sap, null, x.AMOR_HOME_VAL,
                  LS_TEXT, TO_CHAR(SYSDATE,'YYYYMMDD HH24MISS'),  ' ', LS_ROW_ID, to_char(x.last_date,'YYYYMMDD'),
                  x.FILM_TITLE, x.FILM_EPI_TITLE, x.EPI_NO, x.ROW_ID_FILM,
                  x.ROW_ID_EPI, x.PROG_ID, x.last_TIME, null, null, x.RUN_ID ) ;
         EXCEPTION
          WHEN OTHERS THEN
             ERR_CODE   := '20011';
             ERR_NAME   := substr('Err Insert G_SAP_AMRTIZATION --PO NO :'||x.PUR_CONTRACT_NO||
                           ' - PROG_NAME :'||x.FILM_TITLE ,1,100) ||' - EPI NO : '|| to_char(x.epi_no) ;
             ERR_MSG    := SUBSTR(SQLERRM,1,500 );

             INSERT INTO SYN_SAP_ERROR_LOG
               (CODE, NAME, ERROR_REASON, UPDATE_DATE, ROW_ID)
             Values(ERR_CODE, ERR_NAME, ERR_MSG, SYSDATE, GET_ROW_ID()) ;
         END;
    else
         SELECT COUNT(1)  INTO ii
           FROM SYN_G_SAP_AMRTIZATION_V2
          WHERE REF_NO = x.PUR_CONTRACT_NO
            AND row_id_epi= x.row_id_epi
            AND run_id = x.run_id
            AND nvl(SAP_TIMEST,'Ctztx' ) = 'Ctztx'
            ;

        if ii = 0 then
         DELETE SYN_G_SAP_AMRTIZATION_V2
          WHERE REF_NO = x.PUR_CONTRACT_NO
            AND row_id_epi= x.row_id_epi
            AND run_id = x.run_id
            AND nvl(SAP_TIMEST,'Ctztx' ) = 'Ctztx'
            ;

            ll_amort_val :=  x.AMOR_HOME_VAL;
            ll_amort_val_new := ll_amort_val;

            begin
                   select a.sap_code
                      into source_code_sap
                      from INV_SUB_GROUP a
                      where a.PO_SUB_GRP = x.PO_SUB_GRP;
                 exception
                  when others then
                    raise_application_error(-20001,'source '||sqlerrm);
                 end;

                 begin
                   select a.sap_code
                      into major_sap
                      from INV_PO_TYPE a
                      where a.PO_TYPE = x.PUR_TYPE;
                 exception
                  when others then
                    raise_application_error(-20001,'major'||sqlerrm);
                 end;

                 BEGIN
                  INSERT INTO SYN_G_SAP_AMRTIZATION_V2
                   (TRANS_TYPE, REF_NO, ASSIGNMENT, DOC_HDR_TXT, DOC_DATE,
                    CURRENCY, PO_SOURCE, PO_MAJOR, FLG_REVSH, AMOUNT,
                    TEXT1, GEN21_TIMEST, SAP_TIMEST, ROW_ID,PLAY_DATE,
                    FILM_TITLE, FILM_EPI_TITLE, EPI_NO, ROW_ID_FILM,
                    ROW_ID_EPI, PROG_ID, PLAY_TIME, FLAG, SEND_REMARK, RUN_ID)
                   VALUES('C',x.PUR_CONTRACT_NO, x.PROG_ID,x.film_title, to_char(LD_DATE_TO,'YYYYMMDD'),
                          'IDR', source_code_sap, major_sap, null, ll_amort_val_new,
                          LS_TEXT, TO_CHAR(SYSDATE,'YYYYMMDD HH24MISS'),  ' ', LS_ROW_ID, to_char(x.last_date,'YYYYMMDD'),
                          x.FILM_TITLE, x.FILM_EPI_TITLE, x.EPI_NO, x.ROW_ID_FILM,
                          x.ROW_ID_EPI, x.PROG_ID, x.last_TIME, null, null, x.RUN_ID ) ;
                 EXCEPTION
                  WHEN OTHERS THEN
                     ERR_CODE   := '20011';
                     ERR_NAME   := substr('Err Insert G_SAP_AMRTIZATION --PO NO :'||x.PUR_CONTRACT_NO||
                                   ' - PROG_NAME :'||x.FILM_TITLE ,1,100) ||' - EPI NO : '|| to_char(x.epi_no) ;
                     ERR_MSG    := SUBSTR(SQLERRM,1,500 );

                     INSERT INTO SYN_SAP_ERROR_LOG
                       (CODE, NAME, ERROR_REASON, UPDATE_DATE, ROW_ID)
                     Values(ERR_CODE, ERR_NAME, ERR_MSG, SYSDATE, GET_ROW_ID()) ;
                 END;

        else

         DELETE SYN_G_SAP_AMRTIZATION_V2
          WHERE REF_NO = x.PUR_CONTRACT_NO
            AND row_id_epi= x.row_id_epi
            AND run_id = x.run_id
            AND nvl(SAP_TIMEST,'Ctztx' ) = 'Ctztx'
            ;

         SELECT sum(AMOUNT)  INTO ll_amort_val_old
           FROM SYN_G_SAP_AMRTIZATION_V2
          WHERE REF_NO = x.PUR_CONTRACT_NO
            AND row_id_epi= x.row_id_epi
            AND run_id = x.run_id
            AND nvl(SAP_TIMEST,'Ctztx' ) <> 'Ctztx'
            ;

            ll_amort_val :=  x.AMOR_HOME_VAL;
            ll_amort_val_new := ll_amort_val - ll_amort_val_old;

            if ll_amort_val_new <> 0 then

                begin
                   select a.sap_code
                      into source_code_sap
                      from INV_SUB_GROUP a
                      where a.PO_SUB_GRP = x.PO_SUB_GRP;
                 exception
                  when others then
                    raise_application_error(-20001,'source '||sqlerrm);
                 end;

                 begin
                   select a.sap_code
                      into major_sap
                      from INV_PO_TYPE a
                      where a.PO_TYPE = x.PUR_TYPE;
                 exception
                  when others then
                    raise_application_error(-20001,'major'||sqlerrm);
                 end;

                 BEGIN
                  INSERT INTO SYN_G_SAP_AMRTIZATION_V2
                   (TRANS_TYPE, REF_NO, ASSIGNMENT, DOC_HDR_TXT, DOC_DATE,
                    CURRENCY, PO_SOURCE, PO_MAJOR, FLG_REVSH, AMOUNT,
                    TEXT1, GEN21_TIMEST, SAP_TIMEST, ROW_ID,PLAY_DATE,
                    FILM_TITLE, FILM_EPI_TITLE, EPI_NO, ROW_ID_FILM,
                    ROW_ID_EPI, PROG_ID, PLAY_TIME, FLAG, SEND_REMARK, RUN_ID)
                   VALUES('C',x.PUR_CONTRACT_NO, x.PROG_ID,x.film_title, to_char(LD_DATE_TO,'YYYYMMDD'),
                          'IDR', source_code_sap, major_sap, null, ll_amort_val_new,
                          LS_TEXT, TO_CHAR(SYSDATE,'YYYYMMDD HH24MISS'),  ' ', LS_ROW_ID, to_char(x.last_date,'YYYYMMDD'),
                          x.FILM_TITLE, x.FILM_EPI_TITLE, x.EPI_NO, x.ROW_ID_FILM,
                          x.ROW_ID_EPI, x.PROG_ID, x.last_TIME, null, null, x.RUN_ID ) ;
                 EXCEPTION
                  WHEN OTHERS THEN
                     ERR_CODE   := '20011';
                     ERR_NAME   := substr('Err Insert G_SAP_AMRTIZATION --PO NO :'||x.PUR_CONTRACT_NO||
                                   ' - PROG_NAME :'||x.FILM_TITLE ,1,100) ||' - EPI NO : '|| to_char(x.epi_no) ;
                     ERR_MSG    := SUBSTR(SQLERRM,1,500 );

                     INSERT INTO SYN_SAP_ERROR_LOG
                       (CODE, NAME, ERROR_REASON, UPDATE_DATE, ROW_ID)
                     Values(ERR_CODE, ERR_NAME, ERR_MSG, SYSDATE, GET_ROW_ID()) ;
                 END;
            end if;

        end if;


     end if;
    END IF ;

    END;
    end loop;

    COMMIT ;

END PRC_GET_AMORT_PO_V2;
/
