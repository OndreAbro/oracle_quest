CREATE OR REPLACE FUNCTION calculate_worktime_interval
(timezone IN number, from_h IN number, to_h IN number, lunch_at IN number, 
start_time_in IN TIMESTAMP, end_time_in IN TIMESTAMP) 

RETURN INTERVAL DAY TO SECOND
IS
    timer INTERVAL DAY TO SECOND := '+00 00:00:00.000000';
    
    -- Корректировка времени, взятого из базы с учетом часового пояса сотрудника
	start_time TIMESTAMP := start_time_in + NUMTODSINTERVAL(timezone,'HOUR');
    end_time TIMESTAMP := end_time_in + NUMTODSINTERVAL(timezone,'HOUR');
    
    start_date DATE := CAST(start_time AS DATE);
    end_date DATE := CAST(end_time AS DATE);
    current_date DATE := start_date;
    
    -- Переменные, обозначающие границы рабочего дня  
    work_start TIMESTAMP;
    lunch_start TIMESTAMP;
    lunch_end TIMESTAMP;
    work_end TIMESTAMP;
    
BEGIN
    
    -- Этап начат и закончен в выходной день
    IF TO_CHAR(current_date) = TO_CHAR(end_date) 
        AND check_holiday(TO_CHAR(current_date)) THEN NULL;
    
    -- Этап начат и закончен в один рабочий день
    ELSIF TO_CHAR(current_date) = TO_CHAR(end_date) THEN

        work_start := TO_TIMESTAMP( current_date || ' ' || from_h || ':00:00');
        lunch_start := TO_TIMESTAMP( current_date || ' ' || lunch_at || ':00:00');
        lunch_end := TO_TIMESTAMP( current_date || ' ' || (lunch_at + 1) || ':00:00');
        work_end := TO_TIMESTAMP( current_date || ' ' || to_h || ':00:00');
        
        /* Вычисление интервала для каждого варианта попадания 
        start_time и end_time в распорядок дня сотрудника */
        IF end_time < work_start OR start_time > work_end THEN
            NULL;  
        ELSIF start_time < work_start THEN           
            IF end_time > work_start AND end_time <= lunch_start THEN
                timer := timer + (end_time - work_start);
            ELSIF end_time > lunch_start AND end_time <= lunch_end THEN
                timer := timer + (lunch_start - work_start);
            ELSIF end_time > lunch_end AND end_time <= work_end THEN
                timer := timer + (lunch_start - work_start) + (end_time - lunch_end);
            ELSE
                timer := timer + (lunch_start - work_start) + (work_end - lunch_end);
            END IF;
        ELSIF start_time > work_start AND start_time <= lunch_start THEN           
            IF end_time <= lunch_start THEN
                timer := timer + (end_time - start_time);
            ELSIF end_time > lunch_start AND end_time <= lunch_end THEN
                timer := timer + (lunch_start - start_time);
            ELSIF end_time > lunch_end AND end_time <= work_end THEN
                timer := timer + (lunch_start - start_time) + (end_time - lunch_end);
            ELSE
                timer := timer + (lunch_start - start_time) + (work_end - lunch_end);
            END IF; 
        ELSIF start_time > lunch_start AND start_time <= lunch_end THEN           
            IF end_time <= lunch_end THEN
                NULL;
            ELSIF end_time > lunch_end AND end_time <= work_end THEN
                timer := timer + (end_time - lunch_end);
            ELSE
                timer := timer + (work_end - lunch_end);
            END IF;   
        ELSE           
            IF end_time <= work_end THEN
                timer := timer + (end_time - start_time);
            ELSE
                timer := timer + (work_end - start_time);
            END IF; 
        END IF;
    
    -- Этап начат в один день, а закончен в другой       
    ELSE
        WHILE current_date < TO_TIMESTAMP( end_date || ' '  || '00:00:00')
        LOOP
            
            IF check_holiday(TO_CHAR(current_date)) THEN
                NULL;
            
            ELSE
             
                work_start := TO_TIMESTAMP( current_date || ' ' || from_h || ':00:00');
                lunch_start := TO_TIMESTAMP( current_date || ' ' || lunch_at || ':00:00');
                lunch_end := TO_TIMESTAMP( current_date || ' ' || (lunch_at + 1) || ':00:00');
                work_end := TO_TIMESTAMP( current_date || ' ' || to_h || ':00:00');
    
                -- Варианты попадания start_time в распорядок дня  
                IF start_time <= work_start THEN
                    timer := timer + (lunch_start - work_start) + (work_end - lunch_end); 
                ELSIF start_time > work_start AND start_time <= lunch_start THEN
                    timer := timer + (lunch_start - start_time) + (work_end - lunch_end);
                ELSIF start_time > lunch_start AND start_time <= lunch_end THEN
                    timer := timer + (work_end - lunch_end);
                ELSIF start_time > lunch_end AND start_time < work_end THEN
                    timer := timer + (work_end - start_time);
                ELSE
                    null;
                END IF;
                            
            END IF;
            current_date := current_date + 1;
            
            /* Если между start_time и end_time больше 2 рабочих дней, 
            start_time для всех дней между первым и последним 
            равен началу рабочего дня */
            start_time := TO_TIMESTAMP( current_date || ' ' || from_h || ':00:00');
        END LOOP;
        
        -- Вычисление затраченного рабочего времени для последнего дня этапа 
        work_start := TO_TIMESTAMP( end_date || ' ' || from_h || ':00:00');
        lunch_start := TO_TIMESTAMP( end_date || ' ' || lunch_at || ':00:00');
        lunch_end := TO_TIMESTAMP( end_date || ' ' || (lunch_at + 1) || ':00:00');
        work_end := TO_TIMESTAMP( end_date || ' ' || to_h || ':00:00');
        
        -- Варианты попадания end_time в распорядок дня
        IF end_time <= work_start THEN
            NULL;
        ELSIF end_time > work_start AND end_time <= lunch_start THEN
            timer := timer + (end_time - work_start);
        ELSIF end_time > lunch_start AND end_time <= lunch_end THEN
            timer := timer + (lunch_start - work_start);
        ELSIF end_time > lunch_end AND end_time <= work_end THEN
            timer := timer + (lunch_start - work_start) + (end_time - lunch_end);
        ELSE
            timer := timer + (lunch_start - work_start) + (work_end - lunch_end);
        END IF;
        
    END IF;
    
    RETURN timer;
    
END;
/
