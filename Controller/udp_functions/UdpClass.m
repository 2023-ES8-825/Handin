classdef UdpClass
    properties
        net = struct;
        id_list = struct;
    end

    methods
        function obj = UdpClass(settings_file_name, id_file_name, opts)

            arguments
                settings_file_name, id_file_name,
                opts.use_twin = false,
                opts.is_twin = false
            end

            % Select target
            if opts.use_twin == false
                target = "real_system";
            elseif opts.is_twin == false
                target = "twin_controller";
            else
                target = "twin_simulator";
            end
            
            % Load appropriate settings from JSON config
            obj.net = read_json(settings_file_name).(target);

            % Setup receiving UDP ports
            obj.net.HVAC.udp = udpport("datagram",'LocalPort', obj.net.HVAC.rx_port);
            obj.net.HP.udp = udpport("datagram",'LocalPort', obj.net.HP.rx_port);
            
            % Read list of sensor and actuator IDs
            obj.id_list = read_json(id_file_name);
            
            % Send large packet to initialize channel
            if target == "real_system"
                toSend = zeros(255*5,1);
                toSend(1:5:end) = 1:255;

                write(obj.net.HVAC.udp, toSend, "uint8", obj.net.HVAC.IP, obj.net.HVAC.tx_port);
                write(obj.net.HP.udp, toSend, "uint8", obj.net.HP.IP, obj.net.HP.tx_port);

            end
 
        end
    
        function [received_data, obj] = receive(obj) 
            received_data = struct;

            % Wait for udp buffers to recieve data
            while (obj.net.HVAC.udp.NumDatagramsAvailable == 0 || obj.net.HP.udp.NumDatagramsAvailable == 0); end

            % Extract data and concatenate
            packetData_hvac = read(obj.net.HVAC.udp, obj.net.HVAC.udp.NumDatagramsAvailable);
            packetData_hp = read(obj.net.HP.udp, obj.net.HP.udp.NumDatagramsAvailable);

            packetData = [packetData_hp.Data, packetData_hvac.Data];

            % Interpret data and place into struct
            for i = 1:round(length(packetData)/5)
                entry_index = (i-1)*5+1;
                sensor_id = uint8(packetData(entry_index));
                sensor_name = obj.id_list.("x" + sensor_id);
                value_meas = typecast(uint8(packetData(entry_index + 1:entry_index+4)), 'single');

                received_data.(sensor_name) = value_meas;
            end
        end

        function obj = transmit(obj, message)

            [messageBytesHVAC, messageBytesHP] = obj.prepare_message_for_trasmission(message);
     
            totalMessage = [messageBytesHVAC, messageBytesHP];

            % Transmit the message bytes over the UDP ports
            if ~isempty(messageBytesHVAC)
                write(obj.net.HVAC.udp, totalMessage, "uint8", obj.net.HVAC.IP, obj.net.HVAC.tx_port);
            end

            if ~isempty(messageBytesHP)          
                write(obj.net.HP.udp, totalMessage, "uint8", obj.net.HP.IP, obj.net.HP.tx_port);
            end
        end 
    end

    methods (Access = private)
        function [hvac_array, hp_array] = prepare_message_for_trasmission(obj, message)
        
            % Initialize an array to hold the bytes of all the field values
            hp_array = [];
            hvac_array = [];
            
            % Loop through each field and append its value to the message bytes array
            for field = fieldnames(message)'
                % Get the value of the current field
                signal_value = message.(field{1});
                signal_num = obj.get_num_from_id(field{1});
                
                % Convert the value to a 4-byte floating point value
                float_value = single(signal_value);
                
                % Convert the floating point value to a byte array
                uint8_array = typecast(float_value, 'uint8');
                
                % Append the byte array to the relevant message bytes array
                if signal_num >= 70
                    hp_array = [hp_array, signal_num, uint8_array];
                else
                    hvac_array = [hvac_array, signal_num, uint8_array];
                end
            end
        end
       
        function signal_id = get_num_from_id(obj, in_value)

            for key = fieldnames(obj.id_list)'

                iter_value = obj.id_list.(key{1});
                
                % Check if the value matches the input id
                if strcmp(iter_value, in_value)
                    % If the value matches, convert to uint8 and return
                    stripped_key = key{1}(2:end);
                    signal_id = uint8(str2double(stripped_key));
                    return
                end
            end
            
            % If no matching field, return 0
            disp(strcat("No ID found for: ", in_value))
            signal_id = uint8(0);
        end
    end
end    