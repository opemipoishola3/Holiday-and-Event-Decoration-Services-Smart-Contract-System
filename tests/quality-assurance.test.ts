import { describe, it, expect, beforeEach } from "vitest"

let mockQualityState = {}

const mockQualityAssurance = {
  submitFeedback: (
      serviceId,
      overallRating,
      timelinessRating,
      craftsmanshipRating,
      professionalismRating,
      cleanlinessRating,
      communicationRating,
      comments,
      wouldRecommend,
  ) => {
    if (overallRating < 1 || overallRating > 5) return { error: "ERR-INVALID-RATING" }
    if (timelinessRating < 1 || timelinessRating > 5) return { error: "ERR-INVALID-RATING" }
    if (craftsmanshipRating < 1 || craftsmanshipRating > 5) return { error: "ERR-INVALID-RATING" }
    if (professionalismRating < 1 || professionalismRating > 5) return { error: "ERR-INVALID-RATING" }
    if (cleanlinessRating < 1 || cleanlinessRating > 5) return { error: "ERR-INVALID-RATING" }
    if (communicationRating < 1 || communicationRating > 5) return { error: "ERR-INVALID-RATING" }
    
    // Check if service already has feedback
    if (mockQualityState.serviceRatings && mockQualityState.serviceRatings[serviceId]) {
      return { error: "ERR-ALREADY-RATED" }
    }
    
    const feedbackId = mockQualityState.nextFeedbackId || 1
    mockQualityState.nextFeedbackId = feedbackId + 1
    mockQualityState.serviceFeedback = mockQualityState.serviceFeedback || {}
    mockQualityState.serviceFeedback[feedbackId] = {
      serviceId,
      customer: "test-principal",
      overallRating,
      timelinessRating,
      craftsmanshipRating,
      professionalismRating,
      cleanlinessRating,
      communicationRating,
      comments,
      wouldRecommend,
      submittedAt: Date.now(),
      verified: false,
    }
    
    // Update service ratings
    mockQualityState.serviceRatings = mockQualityState.serviceRatings || {}
    mockQualityState.serviceRatings[serviceId] = {
      totalRatings: 1,
      averageRating: overallRating,
      ratingSum: overallRating,
      hasFeedback: true,
      inspectionScore: null,
      qualityCertified: false,
    }
    
    return { success: feedbackId }
  },
  
  conductInspection: (serviceId, checklistItems, overallScore, notes, photosHash) => {
    if (overallScore < 0 || overallScore > 100) return { error: "ERR-INVALID-INPUT" }
    
    const inspectionId = mockQualityState.nextInspectionId || 1
    mockQualityState.nextInspectionId = inspectionId + 1
    mockQualityState.qualityInspections = mockQualityState.qualityInspections || {}
    
    const passed = overallScore >= 75 // Minimum threshold
    const status = passed ? 4 : 3 // INSPECTION-PASSED : INSPECTION-FAILED
    
    mockQualityState.qualityInspections[inspectionId] = {
      serviceId,
      inspector: "test-principal",
      inspectionDate: Date.now(),
      checklistItems,
      overallScore,
      status,
      notes,
      photosHash,
      followUpRequired: overallScore < 80,
    }
    
    // Update service ratings with inspection score
    mockQualityState.serviceRatings = mockQualityState.serviceRatings || {}
    const currentRating = mockQualityState.serviceRatings[serviceId] || {
      totalRatings: 0,
      averageRating: 0,
      ratingSum: 0,
      hasFeedback: false,
      inspectionScore: null,
      qualityCertified: false,
    }
    
    mockQualityState.serviceRatings[serviceId] = {
      ...currentRating,
      inspectionScore: overallScore,
      qualityCertified: passed && currentRating.hasFeedback,
    }
    
    return { success: inspectionId }
  },
  
  reportIssue: (serviceId, issueType, severity, description) => {
    if (severity < 1 || severity > 4) return { error: "ERR-INVALID-INPUT" }
    if (issueType < 1 || issueType > 5) return { error: "ERR-INVALID-INPUT" }
    if (!description || description.length === 0) return { error: "ERR-INVALID-INPUT" }
    
    const issueId = mockQualityState.nextIssueId || 1
    mockQualityState.nextIssueId = issueId + 1
    mockQualityState.qualityIssues = mockQualityState.qualityIssues || {}
    mockQualityState.qualityIssues[issueId] = {
      serviceId,
      reportedBy: "test-principal",
      issueType,
      severity,
      description,
      status: 1, // ISSUE-OPEN
      assignedTo: null,
      resolutionNotes: "",
      createdAt: Date.now(),
      resolvedAt: null,
    }
    
    return { success: issueId }
  },
  
  resolveIssue: (issueId, resolutionNotes) => {
    if (!mockQualityState.qualityIssues || !mockQualityState.qualityIssues[issueId]) {
      return { error: "ERR-INVALID-INPUT" }
    }
    
    const issue = mockQualityState.qualityIssues[issueId]
    if (issue.status !== 2) return { error: "ERR-INVALID-STATUS" } // Must be IN-PROGRESS
    
    mockQualityState.qualityIssues[issueId] = {
      ...issue,
      status: 3, // ISSUE-RESOLVED
      resolutionNotes,
      resolvedAt: Date.now(),
    }
    
    return { success: true }
  },
  
  getFeedback: (feedbackId) => {
    return (mockQualityState.serviceFeedback && mockQualityState.serviceFeedback[feedbackId]) || null
  },
  
  getServiceRatings: (serviceId) => {
    return (mockQualityState.serviceRatings && mockQualityState.serviceRatings[serviceId]) || null
  },
}

describe("Quality Assurance Contract", () => {
  beforeEach(() => {
    mockQualityState = {}
  })
  
  describe("submitFeedback", () => {
    it("should submit feedback successfully", () => {
      const result = mockQualityAssurance.submitFeedback(
          1, // service ID
          5, // overall rating
          4, // timeliness
          5, // craftsmanship
          4, // professionalism
          5, // cleanliness
          4, // communication
          "Excellent service, very professional team!",
          true, // would recommend
      )
      
      expect(result.success).toBe(1)
      expect(mockQualityState.serviceFeedback[1]).toBeDefined()
      expect(mockQualityState.serviceFeedback[1].overallRating).toBe(5)
      expect(mockQualityState.serviceRatings[1]).toBeDefined()
      expect(mockQualityState.serviceRatings[1].hasFeedback).toBe(true)
    })
    
    it("should reject invalid overall rating", () => {
      const result = mockQualityAssurance.submitFeedback(1, 0, 4, 5, 4, 5, 4, "Comments", true)
      expect(result.error).toBe("ERR-INVALID-RATING")
    })
    
    it("should reject invalid timeliness rating", () => {
      const result = mockQualityAssurance.submitFeedback(1, 5, 6, 5, 4, 5, 4, "Comments", true)
      expect(result.error).toBe("ERR-INVALID-RATING")
    })
    
    it("should reject duplicate feedback for same service", () => {
      mockQualityAssurance.submitFeedback(1, 5, 4, 5, 4, 5, 4, "First feedback", true)
      const result = mockQualityAssurance.submitFeedback(1, 4, 3, 4, 3, 4, 3, "Second feedback", false)
      expect(result.error).toBe("ERR-ALREADY-RATED")
    })
  })
  
  describe("conductInspection", () => {
    it("should conduct inspection successfully", () => {
      const checklistItems = [true, true, false, true, true] // 4/5 passed
      const result = mockQualityAssurance.conductInspection(
          1, // service ID
          checklistItems,
          85, // overall score
          "Good installation, minor issue with cable management",
          "photo-hash-123",
      )
      
      expect(result.success).toBe(1)
      expect(mockQualityState.qualityInspections[1]).toBeDefined()
      expect(mockQualityState.qualityInspections[1].overallScore).toBe(85)
      expect(mockQualityState.qualityInspections[1].status).toBe(4) // PASSED
      expect(mockQualityState.serviceRatings[1].inspectionScore).toBe(85)
    })
    
    it("should mark inspection as failed for low score", () => {
      const result = mockQualityAssurance.conductInspection(
          1,
          [true, false, false, true, false],
          60,
          "Multiple issues found",
          null,
      )
      
      expect(result.success).toBe(1)
      expect(mockQualityState.qualityInspections[1].status).toBe(3) // FAILED
      expect(mockQualityState.qualityInspections[1].followUpRequired).toBe(true)
    })
    
    it("should reject invalid score", () => {
      const result = mockQualityAssurance.conductInspection(1, [], 150, "Notes", null)
      expect(result.error).toBe("ERR-INVALID-INPUT")
    })
  })
  
  describe("reportIssue", () => {
    it("should report issue successfully", () => {
      const result = mockQualityAssurance.reportIssue(
          1, // service ID
          2, // issue type
          3, // severity HIGH
          "Lights are flickering intermittently",
      )
      
      expect(result.success).toBe(1)
      expect(mockQualityState.qualityIssues[1]).toBeDefined()
      expect(mockQualityState.qualityIssues[1].severity).toBe(3)
      expect(mockQualityState.qualityIssues[1].status).toBe(1) // OPEN
    })
    
    it("should reject invalid severity", () => {
      const result = mockQualityAssurance.reportIssue(1, 2, 0, "Description")
      expect(result.error).toBe("ERR-INVALID-INPUT")
    })
    
    it("should reject empty description", () => {
      const result = mockQualityAssurance.reportIssue(1, 2, 3, "")
      expect(result.error).toBe("ERR-INVALID-INPUT")
    })
  })
  
  describe("resolveIssue", () => {
    it("should resolve issue successfully", () => {
      // First report and assign an issue
      mockQualityAssurance.reportIssue(1, 2, 3, "Flickering lights")
      // Manually set status to IN-PROGRESS for test
      mockQualityState.qualityIssues[1].status = 2
      
      const result = mockQualityAssurance.resolveIssue(1, "Replaced faulty LED driver")
      expect(result.success).toBe(true)
      expect(mockQualityState.qualityIssues[1].status).toBe(3) // RESOLVED
      expect(mockQualityState.qualityIssues[1].resolutionNotes).toBe("Replaced faulty LED driver")
    })
    
    it("should reject resolving non-existent issue", () => {
      const result = mockQualityAssurance.resolveIssue(999, "Resolution notes")
      expect(result.error).toBe("ERR-INVALID-INPUT")
    })
    
    it("should reject resolving issue not in progress", () => {
      mockQualityAssurance.reportIssue(1, 2, 3, "Issue description")
      const result = mockQualityAssurance.resolveIssue(1, "Resolution notes")
      expect(result.error).toBe("ERR-INVALID-STATUS")
    })
  })
  
  describe("integration tests", () => {
    it("should achieve quality certification with both feedback and inspection", () => {
      // Submit positive feedback
      mockQualityAssurance.submitFeedback(1, 5, 4, 5, 4, 5, 4, "Great service!", true)
      
      // Conduct passing inspection
      mockQualityAssurance.conductInspection(1, [true, true, true, true, true], 90, "Excellent work", null)
      
      const ratings = mockQualityAssurance.getServiceRatings(1)
      expect(ratings.qualityCertified).toBe(true)
      expect(ratings.hasFeedback).toBe(true)
      expect(ratings.inspectionScore).toBe(90)
    })
  })
})
