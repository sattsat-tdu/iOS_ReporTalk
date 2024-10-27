//
//  NotificationManager.swift
//  ReportChat
//
//  Created by SATTSAT on 2024/10/15
//
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private let appManager = AppManager.shared
    
    @Published var notifications: [NotificationModel]? = nil
    
    private let firestore = Firestore.firestore()
    
    private init() {
        self.fetchNotifications()
    }
    
    private func fetchNotifications() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        firestore.collection("notifications")
            .whereField("receiverId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("通知の取得に失敗しました: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                let fetchedNotifications = documents.compactMap { document in
                    try? document.data(as: NotificationModel.self)
                }
                
                // 新しい通知が来た場合のみトースト表示
                if let latestFetchedNotification = fetchedNotifications.first,
                   let latestStoredNotification = self.notifications?.first,
                   latestFetchedNotification.id != latestStoredNotification.id {
                    let newMessage = latestFetchedNotification.message
                    UIApplication.showToast(type: .info, message: newMessage)
                }
                
                self.notifications = fetchedNotifications
            }
    }
    
    //アナウンスの送信
    func sendAnnouncement(to userId: String, message: String) {
        let noticeType = NoticeType.announcement.rawValue
        guard let currentUser = appManager.currentUser else { return }
        let newNotification = NotificationModel(
            senderId: currentUser.id!,
            receiverId: userId,
            message: message,
            url: "",
            noticeType: noticeType,
            timestamp: Date(),
            isRead: false
        )
        do {
            _ = try firestore
                .collection("notifications")
                .addDocument(from: newNotification)
            
            print("\(userId)にアナウンスしました")
        } catch {
            print("アナウンスに失敗しました(NotificationManager) \(error.localizedDescription)")
        }
    }
    
    //友達申請通知の送信
    func sendFriendRequestNotification(to userId: String) {
        let noticeType = NoticeType.friendRequest.rawValue
        guard let currentUser = appManager.currentUser else { return }
        
        let message = "「\(currentUser.userName)」から友達申請が届いています"
        let newNotification = NotificationModel(
            senderId: currentUser.id!,
            receiverId: userId,
            message: message,
            url: "",
            noticeType: noticeType,
            timestamp: Date(),
            isRead: false
        )
        
        do {
            _ = try firestore
                .collection("notifications")
                .addDocument(from: newNotification)
            
            print("\(userId)に友達申請を送りました")
        } catch {
            print("通知の送信に失敗しました: \(error)")
        }
    }
    
    //フレンドリクエストを送っているか確認
    func checkSentFriendRequest(from senderId: String, to receiverId: String) async -> Bool {
        
        do {
            let snapshot = try await firestore
                .collection("notifications")
                .whereField("senderId", isEqualTo: senderId)
                .whereField("receiverId", isEqualTo: receiverId)
                .whereField("noticeType", isEqualTo: NoticeType.friendRequest.rawValue)
                .getDocuments()

            if !snapshot.isEmpty {
                return true //リクエストをすでに送っている
            }
            
            return false
            
        } catch {
            return false
        }
    }
}
