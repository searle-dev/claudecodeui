import { useState, useEffect, useRef } from 'react';

export function useWebSocket() {
  const [ws, setWs] = useState(null);
  const [messages, setMessages] = useState([]);
  const [isConnected, setIsConnected] = useState(false);
  const reconnectTimeoutRef = useRef(null);

  useEffect(() => {
    connect();
    
    return () => {
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (ws) {
        ws.close();
      }
    };
  }, []);

  const connect = async () => {
    try {
      // Determine WebSocket URL based on current environment
      let wsUrl;
      
      // Check if we're in production (domain name, not localhost)
      const isProduction = !window.location.hostname.includes('localhost') && 
                          !window.location.hostname.includes('127.0.0.1');
      
      if (isProduction) {
        // In production, use the same domain with appropriate protocol
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        wsUrl = `${protocol}//${window.location.host}/ws`;
        console.log('Production WebSocket URL:', wsUrl);
      } else {
        // In development, try to get server config first
        try {
          const configResponse = await fetch('/api/config');
          const config = await configResponse.json();
          wsUrl = `${config.wsUrl}/ws`;
          console.log('Development WebSocket URL from config:', wsUrl);
        } catch (error) {
          console.warn('Could not fetch server config, using default development URL');
          const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
          const apiPort = window.location.port === '3001' ? '3002' : (window.location.port || '3008');
          wsUrl = `${protocol}//${window.location.hostname}:${apiPort}/ws`;
          console.log('Development WebSocket URL fallback:', wsUrl);
        }
      }
      
      console.log('Attempting WebSocket connection to:', wsUrl);
      const websocket = new WebSocket(wsUrl);

      websocket.onopen = () => {
        setIsConnected(true);
        setWs(websocket);
      };

      websocket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          setMessages(prev => [...prev, data]);
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
        }
      };

      websocket.onclose = () => {
        setIsConnected(false);
        setWs(null);
        
        // Attempt to reconnect after 3 seconds
        reconnectTimeoutRef.current = setTimeout(() => {
          connect();
        }, 3000);
      };

      websocket.onerror = (error) => {
        console.error('WebSocket error:', error);
      };

    } catch (error) {
      console.error('Error creating WebSocket connection:', error);
    }
  };

  const sendMessage = (message) => {
    if (ws && isConnected) {
      ws.send(JSON.stringify(message));
    } else {
      console.warn('WebSocket not connected');
    }
  };

  return {
    ws,
    sendMessage,
    messages,
    isConnected
  };
}