#!/usr/bin/env python
import rospy
from std_msgs.msg import String
from geometry_msgs.msg  import Twist, Point
from sensor_msgs.msg  import Imu
from nav_msgs.msg import Odometry
from tf.transformations import euler_from_quaternion, quaternion_from_euler
from math import cos,sin
from gazebo_msgs.srv import GetModelState


class ExLoc(object):

  x_gt = 0;
  y_gt = 0;
  theta_gt = 0;

  x_odo = 0;
  y_odo = 0;
  theta_odo = 0;
  
  x_odo_husky = 0.0
  y_odo_husky = 0.0
  theta_odo_husky = 0.0

  x_dr = 0;
  y_dr = 0;
  theta_dr = 0;
  
  v = 0;
  w = 0;
  ts = 0.2;

  def __init__(self):


    rospy.Subscriber("/cmd_vel", Twist, self.odo_cb)
    rospy.Subscriber("/imu/data", Imu, self.imu_cb)   
    rospy.Subscriber("/husky_velocity_controller/odom/", Odometry, self.odo_husky_cb)         
    self.pub_gt = rospy.Publisher('/gt', Point, queue_size=10)
    self.pub_odo = rospy.Publisher('/odo', Point, queue_size=10)
    self.pub_odo_husky = rospy.Publisher('/odo_husky', Point, queue_size=10)
    self.pub_dr = rospy.Publisher('/dr', Point, queue_size=10)





  def get_gt(self):
  
    g_get_state = rospy.ServiceProxy("/gazebo/get_model_state", GetModelState)
    
    rospy.wait_for_service("/gazebo/get_model_state")
    
    try:
            
      state = g_get_state(model_name="husky")
            
    except Exception as e:
        
      rospy.logerr('Error on calling service: %s',str(e))
      return
  
    self.x_gt = state.pose.position.x
    self.y_gt = state.pose.position.y 
    yaw_gt = self.get_rotation(state.pose.orientation)
    self.theta_gt = yaw_gt 
    self.pub_gt.publish(Point(self.x_gt, self.y_gt, self.theta_gt))
    #print(self.theta_gt)    


  def get_dr(self):
    self.x_dr = self.x_dr + self.ts*self.v*cos(self.theta_dr);   
    self.y_dr = self.y_dr + self.ts*self.v*sin(self.theta_dr);   
    self.pub_dr.publish(Point(self.x_dr, self.y_dr, self.theta_dr))  
  
  def odo_husky(self):
    self.pub_odo_husky.publish(Point(self.x_odo_husky, self.y_odo_husky, self.theta_odo_husky))   
    


  def odo_cb(self, msg):
    self.v=msg.linear.x
    self.w=msg.angular.z 
    
    self.x_odo = self.x_odo + self.ts*self.v*cos(self.theta_odo);   
    self.y_odo = self.y_odo + self.ts*self.v*sin(self.theta_odo);   
    self.theta_odo = self.theta_odo + self.ts*self.w;       
    
    self.pub_odo.publish(Point(self.x_odo, self.y_odo, self.theta_odo))
    
    self.get_gt()
    self.get_dr()
    self.odo_husky()


    
  def imu_cb(self, msg):
    yaw_imu = self.get_rotation(msg.orientation)
    self.theta_dr = yaw_imu
  
  def odo_husky_cb(self, msg):
    self.x_odo_husky = msg.pose.pose.position.x
    self.y_odo_husky = msg.pose.pose.position.y
    self.theta_odo_husky = self.get_rotation(msg.pose.pose.orientation)
 
 
 
 
  def get_rotation(self, msg):
    orientation_q = msg
    orientation_list = [orientation_q.x, orientation_q.y, orientation_q.z, orientation_q.w]
    (roll, pitch, yaw) = euler_from_quaternion (orientation_list)
    return(yaw)
  





rospy.init_node('odo_vs_dr', anonymous=True)


el = ExLoc();


# spin() simply keeps python from exiting until this node is stopped
rospy.spin()
